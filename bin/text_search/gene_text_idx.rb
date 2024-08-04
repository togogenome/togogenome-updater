#!/usr/bin/env ruby

require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'
require "#{File.expand_path("..", __FILE__)}/./base.rb"

BASE_DIR = @base_dir = File.expand_path("..", __FILE__)
PREPARE_DIR = "/data/text_search/current/prepare/gene"
OUTPUT_DIR = "/data/text_search/current/gene"
OUTPUT_SOLR_DIR = "#{OUTPUT_DIR}/solr"
TOGO_TAX_JSON = "#{PREPARE_DIR}/json/tax_id_list.json"

@metadata = JSON.parse(File.read("#{BASE_DIR}/gene.json"))
@text_search_base = TextSearchBase.new

def query(query_name, tax_json)
  STDERR.puts "Start: query [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")

  tax_list = JSON.parse(File.read("#{tax_json}"))
  temp_query_file = "#{BASE_DIR}/sparql/gene/temp_sparql_#{query_name}.rq"
  tax_list.each do |tax|
    File.open("#{temp_query_file}", "w") do |f|
      f.puts ERB.new(File.read("#{BASE_DIR}/sparql/gene/#{query_name}.rq.erb")).result(binding)
    end

    FileUtils.mkdir_p("#{PREPARE_DIR}/text/#{query_name}")
    tax_id = tax.split("/").last
    output_file = "#{PREPARE_DIR}/text/#{query_name}/#{tax_id}.txt"

    # prevent freeze with no reply isql
    max_attempts = 3 #retry count
    num_attempts = 0
    begin
      num_attempts += 1
      @text_search_base.isql_query(File.read(temp_query_file), output_file)
      raise if File.read(output_file).include?("Error") # maybe timeout
    rescue
      if num_attempts <= max_attempts
        sleep 3
        retry
      end
    end
  end
  FileUtils.rm("#{temp_query_file}")
  STDERR.puts "End: query [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
end

def create_json (stanza_name,query_names, tax_json)
  STDERR.puts "Start: create json [#{stanza_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
  tax_list = JSON.parse(File.read("#{tax_json}"))
  tax_list.each do |tax|
    tax_id = tax.split("/").last
    result_hash = text2hash(stanza_name,query_names, tax_id)
    if result_hash.size > 0
      output_json(stanza_name, result_hash, tax_id)
    end
  end
  STDERR.puts "End: create json [#{stanza_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
end

# convert a hash object from 1 line text data
def gene_obj_mapping(line, query_name, columns_info)
  return line.start_with?('http://togogenome.org/gene/') unless
  line.force_encoding('UTF-8')
  line = line.encode("UTF-16BE", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '?').encode("UTF-8")
  columns = line.split('^@')
  values = {}
  columns_info.each do |column|
    if column["is_identify"]
      gene_no = columns[column["column_number"]].strip.gsub('http://togogenome.org/gene/','')
      values["@id"] = "http://togogenome.org/gene/#{gene_no}"
      values["gene_id"] = @text_search_base.to_utf(gene_no)
    else # expect id columns are
      value = columns[column["column_number"]].split("|||").map do |entry|
        # irregular case
        if column["column_name"] == 'uniprot_id'
          @text_search_base.to_utf(entry.strip.split('/').last)
        elsif query_name == 'protein_cross_references' && column["column_name"] == 'up_xref_ids'
          @text_search_base.to_utf(entry.strip.split('/').last)
        elsif query_name == 'protein_sequence_annotation' && column["column_name"] == 'up_seq_anno_feature_ids'
          @text_search_base.to_utf(entry.strip.strip.gsub('http://purl.uniprot.org/annotation/',''))
        else
          @text_search_base.to_utf(entry.strip)
        end
      end
      values[column["column_name"]] = value
    end
  end
  values
end

#create hash data from text data of query result
def text2hash (stanza_name,query_names, tax_id)
  result = {}
  #load each query result file
  query_names.each do |query_name|
    input_file = "#{PREPARE_DIR}/text/#{query_name}/#{tax_id}.txt"
    File.open("#{input_file}") do |f|
      while line  = f.gets
        # convert a line to hash object
        columns_info = @text_search_base.get_query_columns(stanza_name, query_name, @metadata)
        gene_text_data = gene_obj_mapping(line, query_name, columns_info)

        gene_id = gene_text_data["gene_id"]
        if result[gene_id] == nil
          result[gene_id] = gene_text_data
        else
          result[gene_id].merge!(gene_text_data) do |key, oldval, newval|
            if key.to_s == 'gene_id' || key.to_s == '@id' # no repeat of tax id
              oldval
            else # concat text data
              oldval.concat(newval).uniq
            end
          end
        end
      end
    end
  end
  result
end

def output_json (stanza_name, result_hash, tax_id)
  #get stanza columns name for jsonld @context data
  columns = @text_search_base.get_stanza_column_names(stanza_name, @metadata)

  #output json file
  FileUtils.mkdir_p("#{OUTPUT_DIR}/#{stanza_name}")
  FileUtils.mkdir_p("#{OUTPUT_SOLR_DIR}/#{stanza_name}")
  output_file  = "#{OUTPUT_DIR}/#{stanza_name}/#{tax_id}.jsonld"
  output_solr_file  = "#{OUTPUT_SOLR_DIR}/#{stanza_name}/#{tax_id}.json"

  @text_search_base.output_file(output_solr_file, output_file, stanza_name, columns, result_hash)
end

@metadata["stanzas"].each do |stanza|
  query_names = []
  stanza["queries"].each do |query|
    query(query["query_name"], "#{TOGO_TAX_JSON}")
    query_names.push(query["query_name"])
  end
  create_json(stanza["stanza_name"], query_names, "#{TOGO_TAX_JSON}");
end

