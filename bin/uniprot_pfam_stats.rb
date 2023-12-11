#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql_isql.rb"
require 'json'
require 'erb'
require 'fileutils'

class UniProtPfamStats

  def initialize(isql_bin_cmd, output_dir)
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @output_dir = output_dir
    FileUtils.mkdir_p("#{@output_dir}")
    @base_dir = File.dirname(__FILE__)
  end

# desc 'get_all_pfam_list', 'UniProtで出現する全てのPfamIDを取得する'
  def get_all_pfam_list
    sparql = File.read("#{@base_dir}/sparql/get_all_pfam_id.rq")
    result = SparqlIsql.isql_query(@isql_cmd, sparql)
    pfam_list = []
    format_tsv(result).split("\n").each do |row|
      pfam_list.push(row.chomp.split("/").last)
    end
    output_file = File.open("#{@output_dir}/pfam_list.json", "w")
    output_file.puts JSON.pretty_generate(pfam_list)
    output_file.flush
    output_file.close
    pfam_list
  end

# desc 'output_pfam_info', '指定されたpfam_idの情報をSPARQLで取得してturtleを出力する'
  def output_pfam_info(pfam_id)
    puts pfam_id
    template = File.read("#{@base_dir}/sparql/get_pfam_info.erb")
    sparql = ERB.new(template).result(binding)
    result = SparqlIsql.isql_query(@isql_cmd, sparql)
    output_ttl(pfam_id, format_tsv(result))
  end

# desc 'output_ttl', '指定されたpfam_idとSPARQLの結果からturtleを組み立ててファイルに出力する'
  def output_ttl(pfam_id, tsv_data)
    protein_list = []
    tsv_data.split("\n").each do |line|
      pfam_info_uri = line.split("\t").last.chomp
      #pfam_info_url e.g. <http://purl.uniprot.org/isoforms/Q8I6U6-1#Pfam_PF07391_match_286>
      local_part = pfam_info_uri.split("/").last
      protein_id = local_part.split("-").first
      hit_count = local_part.split("_").last
      protein_list.push({ protein_id: protein_id, hit_count: hit_count, pfam_info_uri: local_part})
    end
    #matchの後の数値は最大数に達するまで全て出現するため最大数を取得する。570hitだと1〜570までのトリプルが出現するがヒット数としては570を取得する
    #isoforms/Q8I6U6-1#Pfam_PF07391_match_1
    #isoforms/Q8I6U6-1#Pfam_PF07391_match_570
    pfam_info_list = protein_list.group_by{|row| row[:protein_id]}.map do |protein_id, value|
      max_value = value.max {|a, b| a[:hit_count].to_i <=> b[:hit_count].to_i}
      {protein_id: protein_id, hit_count: max_value[:hit_count], pfam_info_uri: max_value[:pfam_info_uri]}
    end

    output_file = File.open("#{@output_dir}/#{pfam_id}.ttl", "w")
    output_file.puts "@prefix sio: <http://semanticscience.org/resource/> ."
    output_file.puts "@prefix uniprot: <http://purl.uniprot.org/uniprot/> ."
    output_file.puts "@prefix up: <http://purl.uniprot.org/core/> ."
    output_file.puts "@prefix pfam: <http://purl.uniprot.org/pfam/> ."
    output_file.puts "@prefix isoforms: <http://purl.uniprot.org/isoforms/> ."
    output_file.puts "@prefix stats:  <http://togogenome.org/stats/> ."
    output_file.puts

    pfam_info_list.each do |item|
      output_file.puts "pfam:#{pfam_id}\tstats:pfam_info\tisoforms:#{item[:pfam_info_uri]} ."
      output_file.puts "isoforms:#{item[:pfam_info_uri]}\tsio:SIO_000068\tuniprot:#{item[:protein_id]} ."
      output_file.puts "isoforms:#{item[:pfam_info_uri]}\tup:hits\t#{item[:hit_count]} ."
      output_file.puts
    end

    output_file.flush
    output_file.close
  end


# desc 'format_tsv', 'SPARQLの結果をTSV形式に変換'
  def format_tsv(str)
    rows = str.split("\n")
    rows.map { |row|
      row.gsub(/\s+/, "\t") + "\n"
    }.join
  end
end

if ARGV.size < 2
 puts "./uniprot_pfam_stats.rb <isql_command> <output_dir> "
 exit(1)
end
pfam_stats = UniProtPfamStats.new(ARGV[0], ARGV[1])
pfam_list = pfam_stats.get_all_pfam_list
pfam_list.each do |pfam_id|
  pfam_stats.output_pfam_info(pfam_id)
end
