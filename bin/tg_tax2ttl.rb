#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql_isql.rb"
require 'json'
require 'erb'
require 'fileutils'

class TG_TAX2RDF

# desc 'setup', 'GenoOntology 毎のUniProt ID をロード'
  def initialize(isql_bin_cmd, output_dir)
    @isql_cmd = isql_bin_cmd + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @output_dir = output_dir
    FileUtils.mkdir_p("#{@output_dir}")
    @base_dir = File.dirname(__FILE__)
  end


# desc 'tg_tax_refseq', 'RefSeqに出現するtax_idとその祖先tax_idの関係をtripleの形式で出力する'
  def refseq_tgtax()
    puts 'start refseq_tgtax'
    sparql = File.read("#{@base_dir}/sparql/tgtax_refseq.rq")
    ttl = SparqlIsql.isql_query(@isql_cmd, sparql)
    gotax_list = []
    file_path = "#{@output_dir}/refseq.tgtax.ttl"
    File.open(file_path, 'w') do |output|
      output << format_ttl(ttl)
    end
    puts 'end refseq_tgtax'
  end

  def environment_tgtax()
    puts 'start environment_tgtax'
    sparql = File.read("#{@base_dir}/sparql/tgtax_environment.rq")
    ttl = SparqlIsql.isql_query(@isql_cmd, sparql)
    gotax_list = []
    file_path = "#{@output_dir}/environment.tgtax.ttl"
    File.open(file_path, 'w') do |output|
      output << format_ttl(ttl)
    end
    puts 'end environment_tgtax'
  end

  def phenotype_tgtax()
    puts 'start phenotype_tgtax'
    sparql = File.read("#{@base_dir}/sparql/tgtax_phenotype.rq")
    ttl = SparqlIsql.isql_query(@isql_cmd, sparql)
    gotax_list = []
    file_path = "#{@output_dir}/phenotype.tgtax.ttl"
    File.open(file_path, 'w') do |output|
      output << format_ttl(ttl)
    end
    puts 'end phenotype_tgtax'
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
tgtax = TG_TAX2RDF.new(ARGV[0], ARGV[1])
tgtax.refseq_tgtax
tgtax.environment_tgtax
tgtax.phenotype_tgtax
