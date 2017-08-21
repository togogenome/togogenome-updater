#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'tempfile'
#require "../sparql.rb"

class TextSearchGenePrepare

ISQL = "/data/store/virtuoso7.1/bin/isql 20711 dba dba"
ENDPOINT = "http://ep.dbcls.jp/sparql-import"

  def initialize()
 #   @endpoint = SPARQL.new(endpoint)
    @isql_cmd = "#{ISQL}" + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @sparql_construct ="/data/store/rdf/togogenome/bin/sparql_construct.rb" 
    @base_dir = "/data/store/rdf/togogenome/bin/text_search"
    @query_dir = "#{@base_dir}/sparql/gene/prepare" 
    @output_dir = "/data/store/rdf/togogenome/text_search/current/prepare"
    @gene_ttl_path = "#{@output_dir}/gene_in_facet.ttl"
    @protein_ttl_path = "#{@output_dir}/protein_in_facet.ttl"
    @tax_id_json_path = "#{@output_dir}/gene/json/tax_id_list.json"
    @protein_gene_json_path = "#{@output_dir}/gene/json/protein_gene.json"
    @protein_gene_ttl_path = "#{@output_dir}/protein_gene.ttl"
    @upgo_reasoner_ttl_path = "#{@output_dir}/up_ontologies_upgo_reasoner.ttl"
    FileUtils.mkdir_p("#{@output_dir}")
    FileUtils.mkdir_p("#{@output_dir}/gene/json")
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end

  def load_ttl(path, graph)
    isql_path = Tempfile.open('isql_file') {|fp|
      fp.puts "log_enable(2, 1);"
      fp.puts "DB.DBA.TTLP_MT(file_to_string_output('#{path}'), '', '#{graph}', 81);"
      fp.puts "checkpoint;"
      fp.path
    }
    system(%Q[#{ISQL} < #{isql_path}])
  end

  def create_gene_in_facet_ttl()
    File.delete("#{@gene_ttl_path}") if File.exist?("#{@gene_ttl_path}")
    File.open("#{@gene_ttl_path}", 'w') do |file|
      file.puts triple("@prefix", "skos:", "<http://www.w3.org/2004/02/skos/core#>")
      file.puts ""
    end

    sparql = File.read("#{@query_dir}/create_gene_in_facet_list.rq")
    result = isql_query(sparql)
    File.open("#{@gene_ttl_path}", 'a') do |file|
      result.lines do |line|
        tg_ref = line.split('^@')
        file.puts triple("<#{tg_ref[0].chomp.strip}>", "skos:exactMatch", "<#{tg_ref[1].chomp.strip}>");
      end
    end
  end

  def load_gene_in_facet_ttl()
    load_ttl("#{@gene_ttl_path}", "http://togogenome.org/graph/text_search/gene_list")
  end

  def create_protein_in_facet_ttl()
    File.delete("#{@protein_ttl_path}") if File.exist?("#{@protein_ttl_path}")
    File.open("#{@protein_ttl_path}", 'w') do |file|
      file.puts triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>")
      file.puts triple("@prefix", "up:", "<http://purl.uniprot.org/core/>")
      file.puts ""
    end

    sparql = File.read("#{@query_dir}/create_protein_in_facet_list.rq")
    result = isql_query(sparql)
    File.open("#{@protein_ttl_path}", 'a') do |file|
      result.lines do |line|
        file.puts triple("<#{line.chomp}>", "rdf:type", "up:Protein");
      end
    end
  end

  def load_protein_in_facet_ttl()
    load_ttl("#{@protein_ttl_path}", "http://togogenome.org/graph/text_search/protein_list")
  end

  def create_tax_id_json()
    sparql = File.read("#{@query_dir}/create_tax_id_list.rq")
    result = isql_query(sparql)
    result_array = []
    result.lines do |line|
      result_array.push(line.chomp.strip)
    end
    File.open("#{@tax_id_json_path}", 'w') do |file|
      file.puts JSON.pretty_generate(result_array)
    end
  end

  def create_protein_gene_json()
    sparql = File.read("#{@query_dir}/create_protein_gene_list.rq")
    result = isql_query(sparql)
    result_hash = {}
    result.lines do |line|
      split_line = line.split('^@')
      uniprot_no = split_line[0].chomp.strip
      togo_gene_nos = split_line[1].chomp.strip.split(',')
      result_hash[uniprot_no] = togo_gene_nos
    end
    File.open("#{@protein_gene_json_path}", 'w') do |file|
      file.puts JSON.pretty_generate(result_hash)
    end
  end

  def create_protein_gene_ttl()
    sparql = File.read("#{@query_dir}/create_protein_gene_mapping.rq")
    result = isql_query(sparql)
    file = File.open("#{@protein_gene_ttl_path}", 'w')
    result.lines do |line|
      split_line = line.split('^@')
      uniprot_no = split_line[0].chomp.strip
      togo_gene = split_line[1].chomp.strip
      file.puts "<#{uniprot_no}> <http://togogenome/uptg_mapping> <#{togo_gene}> ."
    end
  end

  def protein_gene_ttl()
    load_ttl("#{@protein_gene_ttl_path}", "http://togogenome.org/graph/text_search/protein_gene")
  end

  def create_up_reasoner()
    system(%Q[#{@sparql_construct} #{ENDPOINT} #{@query_dir}/up_concept_subclass_reasoner.rq > #{@output_dir}/up_concept_subclass_reasoner.ttl])
    system(%Q[#{@sparql_construct} #{ENDPOINT} #{@query_dir}/up_tax_subclass_reasoner.rq > #{@output_dir}/up_tax_subclass_reasoner.ttl])
    system(%Q[#{@sparql_construct} #{ENDPOINT} #{@query_dir}/up_anno_subclass_reasoner.rq > #{@output_dir}/up_anno_subclass_reasoner.ttl])
  end

  def load_up_reasoner()
    load_ttl("#{@output_dir}/up_concept_subclass_reasoner.ttl", "http://togogenome.org/graph/text_search/up_concept_subclass_reasoner")
    load_ttl("#{@output_dir}/up_tax_subclass_reasoner.ttl", "http://togogenome.org/graph/text_search/up_tax_subclass_reasoner")
    load_ttl("#{@output_dir}/up_anno_subclass_reasoner.ttl", "http://togogenome.org/graph/text_search/up_anno_subclass_reasoner")
  end

  def create_upgo_reasoner()
    File.delete("#{@upgo_reasoner_ttl_path}") if File.exist?("#{@upgo_reasoner_ttl_path}")
    File.open("#{@upgo_reasoner_ttl_path}", 'w') do |file|
      file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
      file.puts triple("@prefix", "up:", "<http://purl.uniprot.org/core/>")
      file.puts ""
    end

    sparql = File.read("#{@query_dir}/up_ontologies_upgo_reasoner.rq")
    result = isql_query(sparql)
    File.open("#{@upgo_reasoner_ttl_path}", 'a') do |file|
      result.lines do |line|
        up_go = line.split('^@')
        if !line.start_with?('http://purl.uniprot.org/uniprot/')
          puts line
          next
        end
        #go_uri = up_go[1].chomp.strip.gsub("http://purl.uniprot.org/go/", "http://purl.obolibrary.org/obo/GO_") # change the prefix on uniprot`
        file.puts triple("<#{up_go[0].chomp.strip}>", "up:classifiedWith", "<#{up_go[1].chomp.strip}>");
      end
    end

    sparql = File.read("#{@query_dir}/up_ontologies_go_subclass_reasoner.rq")
    result = isql_query(sparql)
    File.open("#{@upgo_reasoner_ttl_path}", 'a') do |file|
      result.lines do |line|
        go_root = line.split('^@')
        if !line.start_with?('http://purl.obolibrary.org/obo/GO_')
          puts line
          next
        end
        file.puts triple("<#{go_root[0].chomp.strip}>", "rdfs:subClassOf", "<#{go_root[1].chomp.strip}>");
      end
    end
  end

  def load_upgo_reasoner()
    load_ttl("#{@upgo_reasoner_ttl_path}", "http://togogenome.org/graph/text_search/up_ontologies_upgo_reasoner")
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

prepare = TextSearchGenePrepare.new()
prepare.create_gene_in_facet_ttl() #8min 
prepare.load_gene_in_facet_ttl() #3min
prepare.create_protein_in_facet_ttl() #4min
prepare.load_protein_in_facet_ttl() #1min
prepare.create_protein_gene_json() #11min
prepare.create_protein_gene_ttl() #6 min
prepare.protein_gene_ttl() #2min
prepare.create_up_reasoner() #1min
prepare.load_up_reasoner() #1min
prepare.create_upgo_reasoner() #10min
#prepare.load_upgo_reasoner() #4min
prepare.create_tax_id_json() #1min
