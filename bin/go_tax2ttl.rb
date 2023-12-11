#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql_isql.rb"
require 'json'
require 'erb'
require 'fileutils'

class GO_TAX2RDF

# desc 'setup', 'GenoOntology 毎のUniProt ID をロード'
  def initialize(isql_bin_cmd, output_dir)
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @output_dir = output_dir
    FileUtils.mkdir_p("#{@output_dir}")
    @base_dir = File.dirname(__FILE__)
  end

# desc 'get_tax_list', 'RefSeqで使用されているTaxの一覧を取得する'
  def get_tax_list
    puts 'get_tax_list'
    sparql = File.read("#{@base_dir}/sparql/uptax_tax_list.rq")
    SparqlIsql.isql_query(@isql_cmd, sparql, "#{@output_dir}/gotax_list.txt")
    gotax_list = []
    File.open("#{@output_dir}/gotax_list.txt") do |f|
      f.each_line do |line|
        gotax_list.push(line.chomp.strip)
      end
    end
    puts 'end get_tax_list'
    gotax_list
  end

# desc 'go_tax_list', 'GO毎のUniprotIDを取得し、tripleの形式で出力する'
  def go_tax_list(tax_list)
    puts 'start go_tax_list'
    exec_cnt =0
    tax_list.each do |tax_uri|

      file_path = "#{@output_dir}/go_#{tax_uri.split('/').last}.ttl"
      File.delete(file_path) if File.exist?(file_path)

      template = File.read("#{@base_dir}/sparql/create_ttl_go_tax.rq.erb")
      sparql   = ERB.new(template).result(binding)
      ttl = SparqlIsql.isql_query(@isql_cmd,sparql)
      File.open(file_path, 'a') do |output|
        output << format_ttl(ttl)
      end
    end
    puts 'start go_tax_list'
  end

  private

  def format_ttl(str)
    triples = str.split("\n")
    triples.map { |t|
      t.split[0..2].map {|uri| "<#{uri}>" }.join(' ') + ".\n"
    }.join
  end
end

if ARGV.size < 2
 puts "./go_tax2ttl.rb <isql_command> <output_dir> "
 exit(1)
end
gotax = GO_TAX2RDF.new(ARGV[0], ARGV[1])
tax_list = gotax.get_tax_list
gotax.go_tax_list(tax_list)
