require 'json'
require 'fileutils'

class TogoGenomeUpdateCheck
  @@update_log_dir = "/data/store/rdf/togogenome/update_log"
  def initialize(version)
    @update_ret = {}
    @log_dir = "#{@@update_log_dir}/#{version}"
    @version = version
    begin
      FileUtils.mkdir_p(@log_dir) unless File.exist?(@log_dir)
    rescue
      exit
    end
  end

  def shell_command(command)
    tmp_file = "#{@log_dir}/tmp.txt"
    puts %Q[#{command} > #{tmp_file}]
    system(%Q[#{command} > #{tmp_file}])
    File.read(tmp_file).chomp.strip
  end

  def check
    current_uniprot_dir
    current_refseq_dir
    refseq_wget_failed
    fasta_file_size
    fasta_last_tax
    all_triple_count
    graph_triple_count
    jbrowse_dir_size
    solr_index_updated_date
    solr_index_dir_size
    solr_search_warnning
    update_time
    File.open("#{@log_dir}/update_stats.json", "w") do |out|
      puts JSON.pretty_generate(@update_ret)
      out.puts JSON.pretty_generate(@update_ret)
    end
  end

  # 現在のuniprotディレクトリのバージョン
  def current_uniprot_dir
    ret = shell_command("ls -l /data/store/rdf/uniprot | grep current | awk '{print $11}' | cut -d'/' -f1")
    @update_ret["current_uniprot_dir"] = ret
  end

  # 現在のrefseqディレクトリのバージョン
  def current_refseq_dir
    ret = shell_command("ls -l /data/store/rdf/togogenome/refseq | grep current | awk '{print $11}' | cut -d'/' -f1")
    @update_ret["current_refseq_dir"] = ret
  end

  # RefSeqのwgetが失敗しているものがあるか
  def refseq_wget_failed
    ret = shell_command("grep -n 'failed' /data/store/rdf/togogenome/refseq/current/refseq_wget.log | cut -d'/' -f6 | sort | uniq -c | sort -rn")
    failed_list = []
    # retry回数(5回)以上failedのものがあれば失敗
    ret.split("\n").each do |line|
      if line.split(" ").first.to_i > 5
        failed_list.push(line.split(" ").last)
      end
    end
    @update_ret["refseq_wget_failed"] = failed_list
  end
 
  # FASTAファイルのサイズ
  def fasta_file_size
    ret = shell_command("ls -lh /data/store/rdf/togogenome/refseq/current/refseq.fasta | awk '{print $5}'")
    @update_ret["fasta_file_size"] = ret
  end

  # FASTAファイルが最後まで生成されているか
  def fasta_last_tax
    # fastaファイルの最後のseqのtax_idを取得 999xxx なら最後までfastaファイルが生成されている
    ret = shell_command("tail -n 200000 /data/store/rdf/togogenome/refseq/current/refseq.fasta | grep '>' | tail -n1 | cut -d':' -f4 | cut -d',' -f1")
    @update_ret["fasta_last_tax"] = ret.gsub('"', '')
  end

  # 全トリプルカウント
  def all_triple_count
    isql_opt = "VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout"
    ret = shell_command("/data/store/virtuoso7.1/bin/isql 20711 dba dba #{isql_opt} < /data/store/virtuoso7.1/var/lib/virtuoso/all_triple_count.sql")
    @update_ret["all_triple_count"] = ret
  end

  # 各graphのトリプルカウント
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
    @update_ret["graph_triple_count"] = graph_triple_list
    ret = shell_command("grep togogenome #{output_file} | awk '{print \"|-\\n\"\"|\"$1\"||\"$2}'")
    output_wiki_file = "#{@log_dir}/triple_count.#{@version}_wiki.txt"
    File.open(output_wiki_file, "w") do |f|
      f.puts ret
    end
  end

  # jbrowseのディレクトリのサイズ
  def jbrowse_dir_size
    ret = shell_command("du -sh /data/store/rdf/togogenome/refseq/current/jbrowse/")
    @update_ret["jbrowse_dir_size"] = ret
  end

  # solrのindex更新実行日時
  def solr_index_updated_date
    ret = shell_command("ls -lrt /data/store/rdf/togogenome/text_search/solr_cores_dev/environment_inhabitants/data/index/ | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    @update_ret["solr_index_updated_date"] = ret
  end

  # solrのインデックスディレクトリのサイズ
  def solr_index_dir_size
    size = {}
    ret = shell_command("du -sh /data/store/rdf/togogenome/text_search/current/environment/solr | cut -f1")
    size[:environment] = ret
    ret = shell_command("du -sh /data/store/rdf/togogenome/text_search/current/organism/solr | cut -f1")
    size[:organism] = ret
    ret = shell_command("du -sh /data/store/rdf/togogenome/text_search/current/phenotype/solr | cut -f1")
    size[:phenotype] = ret
    ret = shell_command("du -sh /data/store/rdf/togogenome/text_search/current/gene/solr | cut -f1")
    size[:gene] = ret
    @update_ret["solr_index_dir_size"] = size
  end

  # solrでヒットしないスタンザのリスト
  def solr_search_warnning
    ret = shell_command("ruby /data/store/rdf/togogenome/bin/text_search/test/solr_all_stanza_test.rb dev")
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
    @update_ret["solr_search_warnning"] = error_stanza_name
  end

  # 各処理の実行時間
  def update_time
    time = []
    update_start_time = shell_command("ls -l ../ontology/faldo/current/faldo.ttl | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 1, name: "update_start_time", datetime: update_start_time})
    ontology_end = shell_command("ls -lrt /data/store/rdf/togogenome/isql | tail -n100 | grep 'mpo_descendants' | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 2, name: "ontology_end", datetime: ontology_end})
    uniprot_unzip_end = shell_command("ls -l /data/store/rdf/uniprot/current/| grep uniprot_unzip | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 3, name: "uniprot_unzip_end", datetime: uniprot_unzip_end})
    assembly_report_rsync_end = shell_command("ls -l /data/store/rdf/togogenome/genomes/current/genomes/ASSEMBLY_REPORTS/assembly_summary_genbank.ttl | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 4 , name: "assembly_report_rsync_end", datetime: assembly_report_rsync_end})
    assembly_report_load_end = shell_command("ls -lrt /data/store/rdf/togogenome/refseq/current/ | grep prev_refseq | head -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 5 , name: "assembly_report_load_end", datetime: assembly_report_load_end})
    refseq_wget_end = shell_command("ls -l /data/store/rdf/togogenome/refseq/current/refseq_wget.log | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 6 , name: "refseq_wget_end", datetime: refseq_wget_end})
    refseq_ttl_end = shell_command("ls -l /data/store/rdf/togogenome/refseq/current/refseq2ttl.log | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 7 , name: "refseq_ttl_end", datetime: refseq_ttl_end})
    refseq_load_end = shell_command("ls -lrt /data/store/rdf/togogenome/isql | tail -n100 | grep refseq | grep isql | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 8 , name: "refseq_load_end", datetime: refseq_load_end})
    refseq_stats_end = shell_command("ls -lrt /data/store/rdf/togogenome/isql | tail -n100 | grep -E \"stats-[0-9]{3}.isql\" | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 9 , name: "refseq_stats_end", datetime: refseq_stats_end})
    refseq_fasta_end = shell_command("ls -lrt /data/store/rdf/togogenome/refseq/current/refseq.fasta | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 10 , name: "refseq_fasta_end", datetime: refseq_fasta_end})
    jbrowse_end = shell_command("ls -lrt /data/store/rdf/togogenome/refseq/current/jbrowse/ | grep 999 | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 11 , name: "jbrowse_end", datetime: jbrowse_end})
    refseq2up_ttl_end = shell_command("ls -l /data/store/rdf/togogenome/uniprot/current/refseq.up.ttl | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 12 , name: "refseq2up_ttl_end", datetime: refseq2up_ttl_end})
    refseq2up_load_end = shell_command("ls -lrt /data/store/rdf/togogenome/isql | tail -n100 | grep tgup | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 13 , name: "refseq2up_load_end", datetime: refseq2up_load_end})
    uniprot_download_end = shell_command("ls -l /data/store/rdf/togogenome/uniprot/current/refseq/get_uniport_rdf.log | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 14 , name: "uniprot_download_end", datetime: uniprot_download_end})
    uniprot_stats_end = shell_command("ls -lrt /data/store/rdf/togogenome/uniprot/current/goup/upgo_list.txt | awk '{ print $6\" \"$7\" \"$8}'") #終了が捉えられないので、次の工程の開始時刻
    time.push({no: 15 , name: "uniprot_stats_end", datetime: uniprot_stats_end})
    facet_end = shell_command("ls -lrt /data/store/rdf/togogenome/isql | tail -n100 | grep taxonomy_lite | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 16 , name: "facet_end", datetime: facet_end})
    edgestore_end = shell_command("ls -lrt /data/store/rdf/togogenome/isql | tail -n100 | grep edgestore | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 17 , name: "edgestore_end", datetime: edgestore_end})
    solr_index_end = shell_command("ls -l /data/store/rdf/togogenome/text_search/current/gene | grep protein_general_annotation | tail -n1 | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 18 , name: "solr_index_end", datetime: solr_index_end})
    solr_load_end = shell_command("ls -l /data/store/rdf/togogenome/load_solr2.log | awk '{ print $6\" \"$7\" \"$8}'")
    time.push({no: 19 , name: "solr_load_end", datetime: solr_load_end})
    @update_ret["update_time"] = time
  end
end
check = TogoGenomeUpdateCheck.new(ARGV[0])
check.check

# ruby check_update.rb 2020_05