#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require "#{File.expand_path("..", __FILE__)}/./base.rb"

BASE_DIR = @base_dir = File.expand_path("..", __FILE__)
QUERY_DIR = "#{BASE_DIR}/sparql/organism"
PREPARE_DIR = "/data/text_search/current/prepare/organism"
OUTPUT_DIR = "/data/text_search/current/organism"
OUTPUT_SOLR_DIR = "#{OUTPUT_DIR}/solr"

@metadata = JSON.parse(File.read("#{BASE_DIR}/organism.json"))
@text_search_base = TextSearchBase.new

# query to get text data of stanzas
def query(query_name)
  STDERR.puts "Start: query [#{query_name}]"
  FileUtils.mkdir_p("#{PREPARE_DIR}/text")
  query_file = "#{QUERY_DIR}/#{query_name}.rq"
  output_file = "#{PREPARE_DIR}/text/#{query_name}.txt"
  @text_search_base.isql_query(File.read(query_file), output_file)
  STDERR.puts "End: query [#{query_name}]"
end

def create_json (stanza_name,query_names)
  STDERR.puts "Start: create json [#{stanza_name}]"

  result_hash = text2hash(stanza_name,query_names)
  output_json(stanza_name, result_hash)

  STDERR.puts "End: create json [#{stanza_name}]"
end

# convert a hash object from 1 line text data
#
# return value example {TODO desc}
def organism_obj_mapping(line, query_name, columns_info)
  return line.start_with?('http://identifiers.org/taxonomy/') unless
  line.force_encoding('UTF-8')
  line = line.encode("UTF-16BE", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '?').encode("UTF-8")
  columns = line.split('^@')
  values = {}
  columns_info.each do |column|
    if column["is_identify"]
      tax_no = columns[column["column_number"]].strip.gsub('http://identifiers.org/taxonomy/','')
      values["@id"] = "http://togogenome.org/organism/#{tax_no}"
      values["tax_id"] = @text_search_base.to_utf(tax_no)
    else # expect id columns are
      value = columns[column["column_number"]].split("|||").map do |entry| @text_search_base.to_utf(entry.strip) end
      values[column["column_name"]] = value
    end
  end
  values
end

#create hash data from text data of query result
def text2hash (stanza_name,query_names)
  result = {}
  #load each query result file
  query_names.each do |query_name|
    input_file = "#{PREPARE_DIR}/text/#{query_name}.txt"
    File.open("#{input_file}") do |f|
      while line  = f.gets
        # convert a line to hash object
        columns_info = @text_search_base.get_query_columns(stanza_name, query_name, @metadata)
        tax_text_data = organism_obj_mapping(line, query_name, columns_info)

        tax_id = tax_text_data["tax_id"]
        if result[tax_id] == nil
          result[tax_id] = tax_text_data
        else
          result[tax_id].merge!(tax_text_data) do |key, oldval, newval|
            if key.to_s == 'tax_id' || key.to_s == '@id' # no repeat of tax id
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

def output_json (stanza_name, result_hash)
  #get stanza columns name for jsonld @context data
  columns = @text_search_base.get_stanza_column_names(stanza_name, @metadata)

  #output json file
  FileUtils.mkdir_p("#{OUTPUT_DIR}")
  FileUtils.mkdir_p("#{OUTPUT_SOLR_DIR}")
  output_file  = "#{OUTPUT_DIR}/#{stanza_name}.jsonld"
  output_solr_file  = "#{OUTPUT_SOLR_DIR}/#{stanza_name}.json"

  @text_search_base.output_file(output_solr_file, output_file, stanza_name, columns, result_hash)

end

@metadata["stanzas"].map do |stanza|
  query_names = []
  stanza["queries"].each do |query|
    query(query["query_name"])
    query_names.push(query["query_name"])
  end
  create_json(stanza["stanza_name"], query_names);
end
