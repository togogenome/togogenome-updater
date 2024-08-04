#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'tempfile'
require 'erb'
require "#{File.expand_path("..", __FILE__)}/./base.rb"

class TextSearchGenePrepare

  DOCKER_VIRTUOSO = "docker exec -i togogenome_updater_virtuoso"
  ISQL = "/opt/virtuoso-opensource/bin/isql 1111 dba dba"

  def initialize()
    @isql_cmd = "#{ISQL}" + ' VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
    @base_dir = File.expand_path("..", __FILE__)
    @sparql_construct ="#{@base_dir}/../bin/sparql_construct.rb" 
    @query_dir = "#{@base_dir}/sparql/gene/prepare" 
    @output_dir = "/data/text_search/current/prepare"
    @gene_ttl_path = "#{@output_dir}/gene_in_facet.ttl"
    @protein_ttl_path = "#{@output_dir}/protein_in_facet.ttl"
    @tax_id_json_path = "#{@output_dir}/gene/json/tax_id_list.json"
    @protein_gene_json_path = "#{@output_dir}/gene/json/protein_gene.json"
    @protein_gene_ttl_path = "#{@output_dir}/protein_gene.ttl"
    @upgo_reasoner_ttl_path = "#{@output_dir}/up_ontologies_upgo_reasoner.ttl"
    FileUtils.mkdir_p("#{@output_dir}")
    FileUtils.mkdir_p("#{@output_dir}/gene/json")
    @text_search_base = TextSearchBase.new
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end


  def create_gene_in_facet_ttl()
    File.delete("#{@gene_ttl_path}") if File.exist?("#{@gene_ttl_path}")
    File.open("#{@gene_ttl_path}", 'w') do |file|
      file.puts triple("@prefix", "skos:", "<http://www.w3.org/2004/02/skos/core#>")
      file.puts ""
    end

    sparql = File.read("#{@query_dir}/create_gene_in_facet_list.rq")
    result = @text_search_base.isql_query(sparql)
    File.open("#{@gene_ttl_path}", 'a') do |file|
      result.lines do |line|
        tg_ref = line.split('^@')
        file.puts triple("<#{tg_ref[0].chomp.strip}>", "skos:exactMatch", "<#{tg_ref[1].chomp.strip}>");
      end
    end
  end

  def load_gene_in_facet_ttl()
    @text_search_base.load_ttl("#{@gene_ttl_path}", "http://togogenome.org/graph/text_search/gene_list")
  end

  def create_protein_in_facet_ttl()
    File.delete("#{@protein_ttl_path}") if File.exist?("#{@protein_ttl_path}")
    File.open("#{@protein_ttl_path}", 'w') do |file|
      file.puts triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>")
      file.puts triple("@prefix", "up:", "<http://purl.uniprot.org/core/>")
      file.puts ""
    end

    sparql = File.read("#{@query_dir}/create_protein_in_facet_list.rq")
    result = @text_search_base.isql_query(sparql)
    File.open("#{@protein_ttl_path}", 'a') do |file|
      result.lines do |line|
        file.puts triple("<#{line.chomp}>", "rdf:type", "up:Protein");
      end
    end
  end

  def load_protein_in_facet_ttl()
    @text_search_base.load_ttl("#{@protein_ttl_path}", "http://togogenome.org/graph/text_search/protein_list")
  end

  def create_tax_id_json()
    sparql = File.read("#{@query_dir}/create_tax_id_list.rq")
    result = @text_search_base.isql_query(sparql)
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
    result = @text_search_base.isql_query(sparql)
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
    result = @text_search_base.isql_query(sparql)
    file = File.open("#{@protein_gene_ttl_path}", 'w')
    result.lines do |line|
      split_line = line.split('^@')
      uniprot_no = split_line[0].chomp.strip
      togo_gene = split_line[1].chomp.strip
      file.puts "<#{uniprot_no}> <http://togogenome/uptg_mapping> <#{togo_gene}> ."
    end
  end

  def protein_gene_ttl()
    @text_search_base.load_ttl("#{@protein_gene_ttl_path}", "http://togogenome.org/graph/text_search/protein_gene")
  end

  def create_up_reasoner()
    create_subclassof_reasoner("#{@output_dir}/up_concept_subclass_reasoner.ttl", "#{@query_dir}/up_concept_subclass_reasoner.rq")
    create_subclassof_reasoner("#{@output_dir}/up_anno_subclass_reasoner.ttl", "#{@query_dir}/up_anno_subclass_reasoner.rq")
  end

  # 指定したクエリで取得した2カラムの値を rdfs:subClassOfで繋げたttlファイルを出力すr 
  # <http://purl.uniprot.org/keywords/1>    rdfs:subClassOf <http://purl.uniprot.org/keywords/9993> .
  def create_subclassof_reasoner(output_file, query_file)
    File.delete(output_file) if File.exist?(output_file)
    File.open(output_file, 'w') do |file|
      file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
      file.puts ""
    end

    sparql = File.read(query_file)
    result = @text_search_base.isql_query(sparql)
    File.open(output_file, 'a') do |file|
      result.lines do |line|
        columns = line.chomp.split(" ")
        if columns[0].nil? || !columns[0].start_with?("http")
          p line.chomp
          next
        end
        file.puts triple("<#{columns[0]}>", "rdfs:subClassOf", "<#{columns[1]}>");
      end
    end
  end

  # up taxのsubClassOfは一回のクエリでは取れなくなったので、tax_idを取得後に別クエリでsubClassOfのparent_tax_idを取得してファイルを生成するようにした
  # 多分 uniprotの方でtaxonomy_hieralcalでリーズニングデータがロードされているのでこれはいらない。
  # リーズニングデータに subClassOf*を叩くので重くなっていた。不要だと確認できれば削除する
  def create_up_tax_reasoner()
    output_file = "#{@output_dir}/up_tax_subclass_reasoner.ttl"
    File.delete(output_file) if File.exist?(output_file)
    File.open(output_file, 'w') do |file|
      file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
      file.puts ""
    end
    
    sparql = File.read("#{@query_dir}/up_tax_list.rq") # まずtax_idのリストを取得
    result = @text_search_base.isql_query(sparql)
    result.lines do |line|
      tax = line.chomp
      template = File.read("#{@query_dir}/up_tax_subclass_reasoner.erb") # それらの親をtax_idを取得
      sparql = ERB.new(template).result(binding)
      parent_result = @text_search_base.isql_query(sparql)
      File.open(output_file, 'a') do |file|
        parent_result.lines do |parent_line|
          file.puts triple("<#{tax}>", "rdfs:subClassOf", "<#{parent_line.chomp}>");
        end
      end
    end
  end

  def load_up_reasoner()
    @text_search_base.load_ttl("#{@output_dir}/up_concept_subclass_reasoner.ttl", "http://togogenome.org/graph/text_search/up_concept_subclass_reasoner")
    @text_search_base.load_ttl("#{@output_dir}/up_tax_subclass_reasoner.ttl", "http://togogenome.org/graph/text_search/up_tax_subclass_reasoner")
    @text_search_base.load_ttl("#{@output_dir}/up_anno_subclass_reasoner.ttl", "http://togogenome.org/graph/text_search/up_anno_subclass_reasoner")
  end

  def create_upgo_reasoner()
    File.delete("#{@upgo_reasoner_ttl_path}") if File.exist?("#{@upgo_reasoner_ttl_path}")
    File.open("#{@upgo_reasoner_ttl_path}", 'w') do |file|
      file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
      file.puts triple("@prefix", "up:", "<http://purl.uniprot.org/core/>")
      file.puts ""
    end

    sparql = File.read("#{@query_dir}/up_ontologies_upgo_reasoner.rq")
    result = @text_search_base.isql_query(sparql)
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
    result = @text_search_base.isql_query(sparql)
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
    @text_search_base.load_ttl("#{@upgo_reasoner_ttl_path}", "http://togogenome.org/graph/text_search/up_ontologies_upgo_reasoner")
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
prepare.create_up_tax_reasoner()
prepare.load_up_reasoner() #1min
prepare.create_upgo_reasoner() #10min
prepare.load_upgo_reasoner() #4min
prepare.create_tax_id_json() #1min
