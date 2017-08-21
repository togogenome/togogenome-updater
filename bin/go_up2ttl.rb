#!/usr/bin/env ruby

require 'httpclient'
require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'

class GO_UP2RDF

# desc 'setup', 'GenoOntology 毎のUniProt ID をロード'
  def initialize(ep, isql_bin_cmd, output_dir)
    @sparql_ep = ep
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @output_dir = output_dir
    @base_dir = File.dirname(__FILE__)
  end

# desc 'get_upgo_list', 'Uniprotで使用されているGOの一覧を取得する'
  def get_upgo_list
    puts 'start get_upgo_list'
    sparql = File.read("#{@base_dir}/sparql/upgo_list.rq")
    res = query(sparql)
    puts 'end get_upgo_list'
    res
  end

# desc 'upgo_up_cnt', 'GO毎のUniprotIDヒット件数取得する'
  def upgo_up_cnt(upgo_list)
    puts 'start upgo_up_cnt'
    exec_cnt =0
    ret = upgo_list.map do |upgo|
      upgo_uri = upgo['go']['value']
      template = File.read("#{@base_dir}/sparql/upgo_cnt.rq.erb")
      sparql   = ERB.new(template).result(binding)
      res = isql_query(sparql)
      {upgo_uri: upgo_uri, cnt: res.to_i}
    end
    puts 'end upgo_up_cnt'
    ret
  end

# desc 'upgo_up_list', 'GO毎のUniprotIDを取得し、tripleの形式で出力する'
  def upgo_up_list(upgo_with_cnt_list)
    puts 'start upgo_up_list'
    exec_cnt =0
    upgo_with_cnt_list.each do |upgo_wich_cnt|
      cnt      = upgo_wich_cnt[:cnt]
      next if cnt == 0
      upgo_uri = upgo_wich_cnt[:upgo_uri]
      limit    = 1000000
      FileUtils.mkdir_p @output_dir

      file_path = "#{@output_dir}/#{upgo_uri.split('/').last}_uniprot.ttl"
      File.delete(file_path) if File.exist?(file_path)
      
      0.step(cnt, limit) do |offset|
        template = File.read("#{@base_dir}/sparql/create_ttl_upgo_upid.rq.erb")
        sparql   = ERB.new(template).result(binding)
        ttl = isql_query(sparql)
        File.open(file_path, 'a') do |output|
          output << format_ttl(ttl)
        end
      end
    end
  end

  private
  
  def isql_query(sparql, output_path = nil)
    sparql_path = Tempfile.open('sparql_file') {|fp|
      fp.puts "SPARQL"
      fp.puts sparql
      fp.puts ";"
      fp.path
    }

    if output_path
      system(%Q[#{@isql_cmd} < #{sparql_path} > #{output_path}])
    else
      output_tmp = Tempfile.open('output')
      system(%Q[#{@isql_cmd} < #{sparql_path} > #{output_tmp.path}])
      result = output_tmp.read
      output_tmp.close!
      result
    end
  end

  def query(sparql)
    client = HTTPClient.new
    ret = client.get_content(@sparql_ep,
      {query: { query: sparql}, header: {Accept: 'application/sparql-results+json'}})
    JSON.parse(ret)['results']['bindings']
  end

  def format_ttl(str)
    triples = str.split("\n")
    triples.map { |t|
      t.split[0..2].map {|uri| "<#{uri}>" }.join(' ') + ".\n"
    }.join
  end
end

if ARGV.size < 3
 puts "./go_up2ttl.rb <sparql_endpoint> <isql_command> <output_dir> "
 exit(1)
end
goup = GO_UP2RDF.new(ARGV[0], ARGV[1], ARGV[2])
upgo_list = goup.get_upgo_list
upgo_with_cnt_list = goup.upgo_up_cnt(upgo_list)
goup.upgo_up_list(upgo_with_cnt_list)
