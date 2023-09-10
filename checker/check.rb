require 'socket'
require 'json'
require 'fileutils'
require 'net/http'
require 'uri'
require 'erb'

class UpdateChecker
  @@UNIPROT_PATH = "/data/store/rdf/uniprot/"
  @@BASE_DIR = "/data/store/rdf/togogenome/"
  @@VIRTUOSO_ISQL_PORT = 20710
  @@WEBHOOK_URL = "https://hooks.slack.com/services/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"

  def initialize(uniprot_ver, refseq_ver, check_item)
    @uniprot_ver = uniprot_ver
    @refseq_ver = refseq_ver
    @version = "#{uniprot_ver}_#{refseq_ver}"
    @log_dir = "#{@@BASE_DIR}/logs/update_log/#{@version}"
    @log_file = "#{@log_dir}/update.log"

    @genomes_dir = "#{@@BASE_DIR}/genomes/current/"
    @refseq_dir = "#{@@BASE_DIR}/refseq/current/"
    @uniprot_dir = "#{@@BASE_DIR}/uniprot/current/"
    @text_search_dir = "#{@@BASE_DIR}/text_search/current/"

    @stats_file = "#{@log_dir}/stats.json" # 統計値保存ファイル
    begin
      FileUtils.mkdir_p(@log_dir) unless File.exist?(@log_dir)
      unless File.exist?(@stats_file)
        File.open(@stats_file, "w") do |out|
          out.puts JSON.pretty_generate({"version" => @version})
        end
      end
    rescue
      puts "failed to create log dir"
      exit 1
    end
    
    @stats = JSON.parse(File.read(@stats_file)) # 現在の版の統計値が既にあるなら読み込み
    # 前版の統計値を読み込む
    @previous_stats_file = "#{@@BASE_DIR}/logs/update_log/latest_update_stats.log"
    if File.exist?(@previous_stats_file)
      @previous_stats = JSON.parse(File.read(@previous_stats_file))
    else
      @previous_stats = {}
    end
    check(check_item)
  end

  # エラーメッセージを出力、slack通知して異常終了する
  def error_exit(message)
    output_log(message)
    #notification(message)
    exit 1
  end

  # ログファイルに出力する
  def output_log(text)
    File.open(@log_file, "a") do |out|
      out.puts "#{Time.new().strftime("%FT%R")} #{text}"
    end
  end

  # エラーが起きた時にslackに通知を送る
  def notification(message)
    uri = URI.parse(@@WEBHOOK_URL)
    message_data = {
      'channel' => '#togogenome',
      'username' => 'togogenome updater notification',
      'text' => message 
    }
    Net::HTTP.post_form(uri, 'payload' => message_data.to_json)
  end

  # statsの内容を追加してJSONファイルを更新する
  def update_stats_file(key, value)
    @stats[key] = value
    File.open(@stats_file, "w") do |out|
      out.puts JSON.pretty_generate(@stats)
    end
  end

  # シェルコマンドを実行して、結果を返す。結果はtmp.txtにも出力する
  def shell_command(command)
    tmp_file = "#{@log_dir}/tmp.txt"
    puts %Q[#{command} > #{tmp_file}]
    system(%Q[#{command} > #{tmp_file}])
    File.read(tmp_file).chomp.strip
  end

  # graphのトリプル数を取得して返す
  def graph_triple_count(graph)
    graph_name = "http://togogenome.org/graph/#{graph}"
    File.open("#{@log_dir}/graph_triple_count.sql", "w") do |out|
      out.puts ERB.new(File.read("#{__dir__}/graph_triple_count.sql.erb")).result(binding) # graphを埋め込み
    end

    ret = shell_command("/data/store/virtuoso7.1/bin/isql 20711 dba dba < #{@log_dir}/graph_triple_count.sql")
    output_file = "#{@log_dir}/triple_count_#{graph}.txt"
    File.open(output_file, "w") do |f|
      f.puts ret
    end

    count = 0
    File.open(output_file) do |f|
      f.each_line do |line|
        if line.chomp.strip =~ /^[0-9]+$/
          count = line.chomp.strip.to_i
        end
      end
    end
    count
  end

  # loadができているか. triple数が前版に比べて著しく減少していないかのチェック
  def load_triple_count_check(graph, stats_key_name)
    output_log("Start check load graph #{graph}")
    previous_count = @previous_stats[stats_key_name]
    triple_count = graph_triple_count(graph)
    if triple_count == 0 || (!previous_count.nil? && triple_count < (previous_count * 0.9))
      error_exit("ERROR: Failed to load '#{graph}' graph. triple_count: #{triple_count}")
    end
    update_stats_file(stats_key_name, triple_count)
    output_log("End check load graph #{graph}")
  end

  # fileが存在するか. ファイル(ディレクトリ)のサイズが前版に比べて著しく減少していないか
  def file_size_check(file_path, stats_key_name, task_name)
    output_log("Start check file size. #{task_name}")
    previous_size = @previous_stats[stats_key_name]
    if !File.exist?(file_path)
      error_exit("ERROR: Failed task '#{task_name}'. File not found. files. '#{file_path}'")
    else
      if File.directory?(file_path)
        ret = shell_command("du -s #{file_path}")
        file_size = ret.split(" ").first.to_i
      else
        file_size = File.size(file_path)
      end
      if (!previous_size.nil? && file_size < (previous_size * 0.9))
        error_exit("ERROR: Failed task '#{task_name}'. File size has been reduced compared to the previous version. files. '#{file_path}'. file_size: #{previous_size}, prev file_size: #{previous_size}")
      end
    end
    update_stats_file(stats_key_name, file_size)
    output_log("End check file size. #{task_name}")
  end

  # 引数に従いチェック項目を切り替える
  def check(check_item)
### uniprot fetch ###
    if check_item == "uniprot:unzip"
      uniprot_current_link_ver()
      check_file_path = "#{@@UNIPROT_PATH}/current/uniprot_unzip"
      file_size_check(check_file_path, "uniprot_unzip.size", "uniprot:unzip")
### genomes ###
    elsif check_item == "genomes:prepare" # genomesのttlファイルが生成できているか
      check_file_path = "#{@genomes_dir}/genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.ttl"
      file_size_check(check_file_path, "assembly_summary_refseq.ttl.size", "genomes:prepare")
      check_file_path = "#{@refseq_dir}/genomes/all/GCF/000/001/405"
      file_size_check(check_file_path, "assembly_human.ttl.size", "genomes:prepare")
    elsif check_item == "genomes:load"
      load_triple_count_check("assembly_report", "assembly_report_triple_count")
### refseq ###
    elsif check_item == "refseq:fetch" # refseq_list.jsonが生成できて、fastaがwgetで取得できているか
      refseq_current_link_ver()
      check_file_path = "#{@refseq_dir}/refseq_list.json"
      file_size_check(check_file_path, "refseq_list.json.size", "refseq:fetch")
      check_file_path = "#{@refseq_dir}/refseq.gb"
      file_size_check(check_file_path, "refseq.gb.size", "refseq:fetch")
    elsif check_item == "refseq:refseq2ttl" # refseq ttlが生成できているか
      check_file_path = "#{@refseq_dir}/refseq.ttl/9606/PRJNA168/NC_000001.11.ttl"
      file_size_check(check_file_path, "NC_000001.11.ttl.size", "refseq:refseq2ttl")
    elsif check_item == "refseq:load_refseq"
      load_triple_count_check("refseq", "refseq_triple_count")
    elsif check_item == "refseq:refseq2stats"  # refseqデータからstats ファイルが生成できているか
      check_file_path = "#{@refseq_dir}/refseq.stats.ttl"
      file_size_check(check_file_path, "refseq.stats.ttl.size", "refseq:refseq2stats")
      check_file_path = "#{@refseq_dir}/refseq.stats.gc.ttl"
      file_size_check(check_file_path, "refseq.stats.gc.ttl.size", "refseq:refseq2stats")
      check_file_path = "#{@refseq_dir}/refseq.stats.assembly.ttl"
      file_size_check(check_file_path, "refseq.stats.assembly.ttl.size", "refseq:refseq2stats")
    elsif check_item == "refseq:load_stats"
      load_triple_count_check("stats", "refseq_stats_triple_count")
### refseq.fasta jbrowse ###
    elsif check_item == "refseq:refseq2fasta" # refseq.fasta ファイルが生成できているか
      check_file_path = "#{@refseq_dir}/refseq.fasta"
      file_size_check(check_file_path, "refseq.fastal.size", "refseq:refseq2fasta")
    elsif check_item == "refseq:refseq2jbrowse"
      check_file_path = "#{@refseq_dir}/jbrowse"
      file_size_check(check_file_path, "refseq_jbrowse__dir.size", "refseq:refseq2jbrowse")
### uniprot ###
    elsif check_item == "uniprot:refseq2up" # refseq.up.ttlが生成されているか
      check_file_path = "#{@uniprot_dir}/refseq.up.ttl"
      file_size_check(check_file_path, "refseq.up.ttl.size", "uniprot:refseq2up")
    elsif check_item == "uniprot:load_tgup"
      load_triple_count_check("tgup", "tgup_triple_count")
    elsif check_item == "uniprot:download_rdf" # uniprot の rdfがダウンロードできているか
      check_file_path = "#{@uniprot_dir}/refseq/9606.rdf.gz"
      file_size_check(check_file_path, "uniprot_9606.rdf.gz.size", "uniprot:download_rdf")
    elsif check_item == "uniprot:load"
      load_triple_count_check("uniprot", "uniprot_triple_count")
    elsif check_item == "uniprot:uniprot2stats" # uniprot の pfam stats が生成できているか
      check_file_path = "#{@uniprot_dir}/pfam_stats"
      file_size_check(check_file_path, "uniprot_pfam_stats.size", "uniprot:uniprot2stats")
    elsif check_item == "uniprot:load_stats"
      load_triple_count_check("stats", "all_stats_triple_count")
### linkage ###
    elsif check_item == "linkage:goup"
      check_file_path = "#{@uniprot_dir}/goup"  # goup ttlが生成されているか
      file_size_check(check_file_path, "uniprot_goup.size", "linkage:goup")
    elsif check_item == "linkage:load_goup"
      load_triple_count_check("goup", "goup_triple_count")
    elsif check_item == "linkage:tgtax"  # tgtax.ttlが生成されているか
      check_file_path = "#{@refseq_dir}/refseq.tgtax.ttl"
      file_size_check(check_file_path, "refseq.tgtax.ttl.size", "linkage:tgtax")
      check_file_path = "#{@refseq_dir}/environment.tgtax.ttl"
      file_size_check(check_file_path, "environment.tgtax.ttl.size", "linkage:tgtax")
      check_file_path = "#{@refseq_dir}/phenotype.tgtax.ttl"
      file_size_check(check_file_path, "phenotype.tgtax.ttl.size", "linkage:tgtax")
    elsif check_item == "linkage:load_tgtax"
      load_triple_count_check("tgup", "tgup_triple_count")
    elsif check_item == "linkage:gotax"  # gotax ttlが生成されているか
      check_file_path = "#{@uniprot_dir}/gotax"
      file_size_check(check_file_path, "uniprot_gotax.size", "linkage:gotax")
    elsif check_item == "linkage:load_gotax"
      load_triple_count_check("gotax", "gotax_triple_count")
    elsif check_item == "linkage:taxonomy_lite" # taxonomy_lite ttlが生成されているか
      check_file_path = "#{@refseq_dir}/taxonomy_lite.ttl"
      file_size_check(check_file_path, "taxonomy_lite.size", "linkage:taxonomy_lite")
    elsif check_item == "linkage:load_taxonomy_lite"
      load_triple_count_check("taxonomy_lite", "taxonomy_lite_triple_count")
### text_search ###
    elsif check_item == "text_search:update"
      check_file_path = "#{@text_search_dir}/environment"
      file_size_check(check_file_path, "text_search_environment.size", "text_search:updat:environment")
      check_file_path = "#{@text_search_dir}/phenotype"
      file_size_check(check_file_path, "text_search_phenotype.size", "text_search:updat:phenotype")
      check_file_path = "#{@text_search_dir}/organism"
      file_size_check(check_file_path, "text_search_organism.size", "text_search:updat:organism")
      check_file_path = "#{@text_search_dir}/gene"
      file_size_check(check_file_path, "text_search_gene.size", "text_search:updat:gene")
### update完了時 ###
    elsif check_item == "finish"
      # statsファイルのシンボリックリンクを更新する
      File.delete(@previous_stats_file) if File.symlink?(@previous_stats_file)
      File.symlink(@stats_file, @previous_stats_file)
      #
      all_triple_count
      graph_triple_count
    else
    end
  end

  # uniprot のバージョンディレクトリのチェック
  def uniprot_current_link_ver
    link_path = File.readlink("#{@@UNIPROT_PATH}/current")
    if link_path != @uniprot_ver
      error_exit("ERROR: uniprot current symbolic link is unmatch: '#{link_path}' : '#{@uniprot_ver}'")
    end
    update_stats_file("current_uniprot_dir", link_path)
  end

  # refseq のバージョンディレクトリのチェック
  def refseq_current_link_ver
    link_path = File.readlink("#{@@BASE_DIR}/refseq/current")
    if link_path != "release#{@refseq_ver}"
      error_exit("ERROR: uniprot current symbolic link is unmatch: '#{link_path}' : '#{@refseq_ver}'")
    end
    update_stats_file("current_refseq_dir", link_path)
  end

  # 全トリプル数を取得
  def all_triple_count
    isql_opt = "VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout"
    ret = shell_command("/data/store/virtuoso7.1/bin/isql 20711 dba dba #{isql_opt} < /data/store/virtuoso7.1/var/lib/virtuoso/all_triple_count.sql")
    update_stats_file("all_triple_count", ret)
  end

  # 各graphのトリプル数を取得
  def graph_triple_count
    ret = shell_command("/data/store/virtuoso7.1/bin/isql 20711 dba dba < /data/store/virtuoso7.1/var/lib/virtuoso/triple_count.sql")
    output_file = "#{@log_dir}/triple_count.#{@version}.txt"
    File.open(output_file, "w") do |f|
      f.puts ret
    end
    graph_triple_list = []
    File.read(output_file).split("\n").each do |line|
      if line.include?("http://togogenome.org/graph")
        columns = line.chomp.strip.split(" ")
        graph_triple_list.push({graph_name: columns.first, count: columns.last})
      end
    end
    update_stats_file("graph_triple_count", graph_triple_list)
    ret = shell_command("grep togogenome #{output_file} | awk '{print \"|-\\n\"\"|\"$1\"||\"$2}'")
    output_wiki_file = "#{@log_dir}/triple_count.#{@version}_wiki.txt"
    File.open(output_wiki_file, "w") do |f|
      f.puts ret
    end
  end

  # solrでヒットしないスタンザのリストを出力
  def solr_search_warnning
    ret = shell_command("ruby #{@@BASE_DIR}/bin/text_search/test/solr_all_stanza_test.rb dev")
    output_file = "#{@log_dir}/solr_search_result.#{@version}.txt"
    File.open(output_file, "w") do |f|
      f.puts ret
    end
    error_stanza_name = []
    lines = File.read(output_file).split("\n")
    lines.each_with_index do |line, idx|
      if line.chomp.strip.start_with?("WARNING")
        error_stanza_name.push(lines[idx-1].chomp.strip)
      end
    end
    update_stats_file("solr_search_warnning", error_stanza_name)
  end
end

unless ARGV.size == 3
  puts "USAGE; ruby check.rb 2023_02 219 uniprot:unzip"
  exit 1
end
uniprot_ver = ARGV[0]
refseq_ver = ARGV[1]
check_item = ARGV[2]
checker = UpdateChecker.new(uniprot_ver, refseq_ver, check_item)
