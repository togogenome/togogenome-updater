#!/usr/bin/env ruby

require 'httpclient'
require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'

class TG_UP2RDF

# desc 'setup', 'GenoOntology 毎のUniProt ID をロード'
  def initialize(ep, isql_bin_cmd, output_file)
    @sparql_ep = ep
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @output = output_file
    @base_dir = File.dirname(__FILE__)
  end

# desc 'get_feature_count', 'Refseqの主要feature数を取得する'
  def get_feature_count
    sparql = File.read("#{@base_dir}/sparql/tgup_feature_cnt.rq")
    count = isql_query(sparql)
    #count = query(sparql).first['count']['value'].to_i
    count.strip.to_i
  end

# desc 'refseq_cds_list', 'RefseqでProteinIDを持つCDS数を取得する'
  def refseq_cds_list 
    cnt = get_feature_count()
    puts "number of features: " + cnt.to_s
    limit    = 1000000
    
    output_file = File.open(@output, "w")     
      
    0.step(cnt, limit) do |offset|
      puts "offset: " + offset.to_s
      template = File.read("#{@base_dir}/sparql/create_refseq2up_tsv.rq.erb")
      sparql   = ERB.new(template).result(binding)
      result = isql_query(sparql)
      output_file.puts format_tsv(result)
    end
    output_file.close
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

  def format_tsv(str)
    rows = str.split("\n")
    rows.map { |row|
      row.gsub(/\s+/, "\t") + "\n"
    }.join
  end
end

if ARGV.size < 3
 puts "./tg_up2ttl.rb <sparql_endpoint> <isql_command> <output_dir> "
 exit(1)
end
tgup = TG_UP2RDF.new(ARGV[0], ARGV[1], ARGV[2])
tgup = tgup.refseq_cds_list
