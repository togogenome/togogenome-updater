#!/usr/bin/env ruby

require 'httpclient'
require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'

class GO_TAX2RDF

# desc 'setup', 'GenoOntology 毎のUniProt ID をロード'
  def initialize(ep, isql_bin_cmd, output_dir)
    @sparql_ep = ep
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @output_dir = output_dir
    @base_dir = File.dirname(__FILE__)
  end

# desc 'get_tax_list', 'RefSeqで使用されているTaxの一覧を取得する'
  def get_tax_list
    puts 'get_tax_list'
    sparql = File.read("#{@base_dir}/sparql/uptax_tax_list.rq")
    res = query(sparql)
  end

# desc 'go_tax_list', 'GO毎のUniprotIDを取得し、tripleの形式で出力する'
  def go_tax_list(tax_list)
    exec_cnt =0
    tax_list.each do |tax|
      tax_uri = tax['tax_id']['value']
      FileUtils.mkdir_p @output_dir

      file_path = "#{@output_dir}/go_#{tax_uri.split('/').last}.ttl"
      File.delete(file_path) if File.exist?(file_path)
      
      template = File.read("#{@base_dir}/sparql/create_ttl_go_tax.rq.erb")
      sparql   = ERB.new(template).result(binding)
      ttl = isql_query(sparql)
      File.open(file_path, 'a') do |output|
        output << format_ttl(ttl)
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
 puts "./go_tax2ttl.rb <sparql_endpoint> <isql_command> <output_dir> "
 exit(1)
end
gotax = GO_TAX2RDF.new(ARGV[0], ARGV[1], ARGV[2])
tax_list = gotax.get_tax_list
gotax.go_tax_list(tax_list)
