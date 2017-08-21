#!/usr/bin/env ruby


require 'httpclient'
require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'
require "../sparql.rb"

class GeneTextSearch

  def initialize(endpoint, isql_bin_cmd, gene_list_path)
    @endpoint = SPARQL.new(endpoint)
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'#
    @gene_list_path = gene_list_path
    @base_dir = File.dirname(__FILE__)
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end

  def gene_cnt()
    sparql = "#{@base_dir}/sparql/get_gene_cnt.rq"
    result = ""

    @endpoint.query(File.read(sparql), :format => 'json') do |json|
      result += json
    end

    results = JSON.parse(result)["results"]["bindings"]
    gene_cnt = results.first['count']['value']
    gene_cnt
  end

  def gene_list(gene_cnt)
    cnt = gene_cnt.to_i
    limit  = 100000
    #File.delete("#{@gene_list_path}") if File.exist?("#{@gene_list_path}")
#    File.open("#{@gene_list_path}", 'w') do |output|
#      output << triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
#      output << triple("@prefix", "insdc:", "<http://ddbj.nig.ac.jp/ontologies/nucleotide/>")
#    end
     puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
     puts triple("@prefix", "insdc:", "<http://ddbj.nig.ac.jp/ontologies/nucleotide/>")

    0.step(cnt, limit) do |offset|
      template = File.read("#{@base_dir}/sparql/get_gene_list.erb")
      sparql   = ERB.new(template).result(binding)
      result = isql_query(sparql)
#      File.open("#{@gene_list_path}", 'a') do |output|
      result.lines do |line|
       puts triple("<#{line.chomp}>", "rdfs:type", "insdc:Gene");
      end
#        output << result
#      end
    end
  end

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
end


gene_text = GeneTextSearch.new(ARGV[0], ARGV[1], ARGV[2])
gene_cnt = gene_text.gene_cnt();
gene_text.gene_list(gene_cnt)
