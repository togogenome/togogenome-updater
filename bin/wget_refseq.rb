#!/usr/bin/env ruby

require 'net/http'
require 'net/https'
require 'json'
require 'fileutils'
require 'systemu'
require 'date'

class WGET_REFSEQ

  def initialize(refseq_json, output_dir, use_previous_file)
    @refseq_list_path = refseq_json
    @refseq_list = open("#{refseq_json}") do |io|
      JSON.load(io)
    end
    @output_dir = output_dir
    @previous_dir = nil
    # 前バージョンのディレクトからファイルをコピーした場合は直近のバージョンのディレクトリを探索する
    if use_previous_file == "true"
      begin
        refseq_prev_dir = nil
        #currentリンクを指すディレクトリを検索
        current_refseq_dir = File.absolute_path("../", "#{@refseq_list_path}")
        if File.exists?(current_refseq_dir) && File.ftype(current_refseq_dir) == 'link' then
          current_ver_link = File.readlink(current_refseq_dir).split("/").last #releaseXX
          current_ver_num = current_ver_link.gsub("release","")
          refseq_dir = File.absolute_path("../../", "#{@refseq_list_path}")
          #数値を一つずつ減らして直近のバージョンのディレクトリを探す
          (current_ver_num.to_i - 1).downto(1){|ver|
            if File.exist?("#{refseq_dir}/release#{ver.to_s}")
              refseq_prev_dir = "#{refseq_dir}/release#{ver.to_s}"
              break
            end
          }
        end
        unless refseq_prev_dir.nil?
          @previous_dir = refseq_prev_dir
        end
      rescue => ex
        puts "can't find previous version file!"
      end
    else
      @previous_dir = nil
    end
    puts "previous_dir:#{@previous_dir}"
  end

  def wget_all
    #continue until the data can't be get(nothing to wget or failed all of tried).
    success_cnt = 0
    begin
      success_cnt = wget_togows()
      puts "success_cnt: #{success_cnt}"
    end while success_cnt > 0
  end

  # EutilsAPIを使ってRefSeqID毎の最終更新日を取得してrefseq_listに追加する
  # 前回バージョンのGenBankファイルの日付を見比べて同一であれば内容変更なしとしてwgetでダウンロードせずにファイルコピーする(高速化)
  def get_latest_version()
    eutils_url = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=nuccore&retmode=json&id="
    @refseq_list.each_slice(100) do |sliced_seq|
      num_attempts = 0
      begin
        num_attempts += 1
        seq_ids = sliced_seq.map{|seq| seq["refseq_id"]}.join(",")
        res = http_get_response(eutils_url + seq_ids)
        unless res.code =~ /^5/ || res.code =~ /^4/ #error
          result_json = JSON.parse(res.body)
          uids = result_json["result"]["uids"]
          uids.each do |uid|
            seq_summary = result_json["result"][uid]
            seq_id = seq_summary["accessionversion"]
            update_date = seq_summary["updatedate"]
            match_list = sliced_seq.select{|refseq_info| refseq_info["refseq_id"] == seq_id}
            if match_list.size == 1
              match_list.first["update_date"] = update_date
            end
          end
        end
      rescue => ex
        if num_attempts <= 3
          p "retry eutils to get refseq summary"
          sleep 10
          retry
        end
      end
    end
    # ファイルに残してクラス変数にも確保　
    File.open(@refseq_list_path, "w") do |file|
      file.puts JSON.pretty_generate(@refseq_list)
    end
    @refseq_hash = @refseq_list.group_by{|item| item["refseq_id"]}
  end

  def http_get_response (uri)
    #error and cache
    url = URI.parse(uri)
    req = Net::HTTP::Get.new(url)
    ssl_flag = false
    ssl_flag = true if uri.start_with?("https")
    res = Net::HTTP.start(url.host, url.port, :use_ssl => ssl_flag) {|http|
      http.request(req)
    }
    res
  end

  # 前回バージョンのGenBankファイルの日付を取得する
  def get_prev_version()
    current_refseq_dir = File.absolute_path("../", "#{@refseq_list_path}")
    file_path = "#{current_refseq_dir}/prev_refseq_date_list.txt"
    # GenBankファイルの最初の一行を取得し、RefSeqのID(バージョン無し)と更新日を取得する
    system(%Q[find #{@previous_dir}/refseq.gb -type f | xargs head -n1 | grep -A1 "==>" | grep -v "==>" | grep -v "^--" | awk '{print $2\":\"$8}' > #{current_refseq_dir}/prev_refseq_date_list.txt ])
    prev_refseq_hash = {}
    if File.exist?(file_path)
      File.open(file_path) do |file|
        file.each do |line|
          begin
            refseq_id = line.split(":").first.chomp.strip
            update_date = line.split(":").last.chomp.strip
            # GenBankの日付形式からeutilsの日付形式に揃える "17-APR-2017" => "2017/04/17"
            parsed_date = Date.parse(update_date)
            formated_date = parsed_date.strftime("%Y/%m/%d")
            prev_refseq_hash[refseq_id] = formated_date
          rescue => ex
            # skip
          end
        end
      end
      # ファイルに残してクラス変数にも確保　
      File.open("#{current_refseq_dir}/prev_refseq_date_list.json", "w") do |file|
        file.puts JSON.pretty_generate(prev_refseq_hash)
      end
      @prev_refseq_hash = prev_refseq_hash
    end
  end

  def use_previous_file?(tax_id, prj_id, seq_id)
    ret = false
    if !@previous_dir.nil? && !@refseq_hash.nil? && !@prev_refseq_hash.nil?
      if !@refseq_hash[seq_id].nil?
        latest_date = @refseq_hash[seq_id].first["update_date"]
        prev_date = @prev_refseq_hash[seq_id.split(".").first]
        exist = File.exist?("#{@previous_dir}/refseq.gb/#{tax_id}/#{prj_id}/#{seq_id}")
        if latest_date == prev_date && exist
          ret = true
        end
      end
    end
    ret
  end

  def wget_togows()
    cnt = 0 # number of success
    @refseq_list.each do |entry|
      tax_id = entry['tax_id']
      prj_id = entry['bioproject_id']
      FileUtils.mkdir_p("#{@output_dir}/#{tax_id}/#{prj_id}")

      Dir.chdir("#{@output_dir}/#{tax_id}/#{prj_id}") {
        seq_id = entry['refseq_id']
        if !(File.exist?("#{seq_id}")) then #ignore already exist
          if use_previous_file?(tax_id, prj_id, seq_id)
            puts "link previous file #{seq_id} ..."
            system("ln #{@previous_dir}/refseq.gb/#{tax_id}/#{prj_id}/#{seq_id} ./") unless $DEBUG
            cnt += 1
          else
            puts "try wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id} ..."
            system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
            if (File.exist?("#{seq_id}")) then # wget success
              error_line_num = %Q[grep -e "DOCTYPE html" -e "Timeout" #{seq_id} | wc -l] # if wget finished with 500, will appear line "<!DOCTYPE html PUBLIC"
              status, stdout, stderr = systemu error_line_num
              if stdout.to_i > 0 # wget error in the middle
                puts "failed (in the middle) wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
                # file remove and clear cache, then this file will be retried.
                FileUtils.rm("#{@output_dir}/#{tax_id}/#{prj_id}/#{seq_id}")
                system("curl \"http://togows.dbcls.jp/entry/nucleotide/#{seq_id}?clear\"")
              else
                puts "succeed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
                cnt += 1
              end
            else # maybe wget timeout
              puts "failed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
            end
          end
        end
      }
    end
    cnt
  end
end

unless ARGV.size >= 3
 puts "./wget_refseq.rb <refseq_list_json> <output_dir> <use_previous_dir[true|false]>"
 exit(1)
end
wget_refseq = WGET_REFSEQ.new(ARGV[0], ARGV[1], ARGV[2])
wget_refseq.get_prev_version()
wget_refseq.get_latest_version()
wget_refseq.wget_all()
