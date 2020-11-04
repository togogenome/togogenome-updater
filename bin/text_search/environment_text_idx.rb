#!/usr/bin/env ruby

require 'json'
require 'fileutils'

ISQL = '/data/store/virtuoso7.1/bin/isql 20711 dba dba'
ISQL_OPT = 'VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stderr'
TOGO_DIR = '/data/store/rdf/togogenome'
BASE_DIR = "#{TOGO_DIR}/bin/text_search"
QUERY_DIR = "#{BASE_DIR}/sparql/environment"
PREPARE_DIR = "#{TOGO_DIR}/text_search/current/prepare/environment"
OUTPUT_DIR = "#{TOGO_DIR}/text_search/current/environment"
OUTPUT_SOLR_DIR = "#{OUTPUT_DIR}/solr"

@metadata = JSON.parse(File.read("#{BASE_DIR}/environment.json"))

# query to get text data of stanzas
def query(query_name)
  STDERR.puts "Start: query [#{query_name}]"
  FileUtils.mkdir_p("#{PREPARE_DIR}/text")
  query_file = "#{QUERY_DIR}/#{query_name}.rq"
  output_file = "#{PREPARE_DIR}/text/#{query_name}.txt"
  system(%Q[#{ISQL} #{ISQL_OPT} < #{query_file} > #{output_file}])
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
# return value example
# {"@id"=>"http://togogenome.org/environment/MEO_0000368",
#  "meo_id"=>"MEO_0000368",
#  "source_ids"=>["JCM 7370", "JCM 7513"],
#  "organism_names"=>["Sphingomonas adhaesiva Yabuuchi et al. 1990", "Sphingomonas sp."],
#  "isolations"=>["Sterile water used before surgery"],
#  "meo_labels"=>["sterile water"]}
def environment_obj_mapping(line, query_name, columns_info)
  return line.start_with?('http://purl.jp/bio/11/meo/') unless
  line.force_encoding('UTF-8')
  line = line.encode("UTF-16BE", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '?').encode("UTF-8")
  columns = line.split('^@')
  values = {}
  columns_info.each do |column|
    if column["is_identify"]
      meo_no = columns[column["column_number"]].strip.gsub('http://purl.jp/bio/11/meo/','')
      values["@id"] = "http://togogenome.org/environment/#{meo_no}"
      values["meo_id"] = to_utf(meo_no)
    else # expect id columns are
      value = columns[column["column_number"]].split("|||").map do |entry| to_utf(entry.strip) end
      values[column["column_name"]] = value
    end
  end
  values
end

### TODO below methods move to parent class?

def to_utf(str)
  str.force_encoding('UTF-8')
end

# get columns setting of query
def get_query_columns(stanza_name,query_name)
  query_column_info = {}
  @metadata["stanzas"].map do |stanza|
    if stanza_name == stanza["stanza_name"]
      stanza["queries"].each do |query|
        if query_name == query["query_name"]
          query_column_info = query["columns"]
        end
      end
    end
  end
  query_column_info
end

# returns column names of stanza
def get_stanza_column_names (stanza_name)
  columns = []
  @metadata["stanzas"].map do |stanza|
    if stanza_name == stanza["stanza_name"]
      stanza["queries"].each do |query|
        query["columns"].each do |column|
          columns.push(column["column_name"])
        end
      end
    end
  end
  columns.uniq
end

# returns context hash for jsonld
def get_context_hash(stanza_name, column_names)
  base_url = "http://togogenome.org/#{stanza_name}"

  hash = {}
  column_names.each do |column_name|
    hash[column_name] = "#{base_url}/#{column_name}"
  end
  hash
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
        columns_info = get_query_columns(stanza_name, query_name)
        meo_text_data = environment_obj_mapping(line, query_name, columns_info)

        meo_id = meo_text_data["meo_id"]
        if result[meo_id] == nil
          result[meo_id] = meo_text_data
        else
          result[meo_id].merge!(meo_text_data) do |key, oldval, newval|
            if key.to_s == 'meo_id' || key.to_s == '@id' # no repeat of meo id
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
  columns = get_stanza_column_names(stanza_name)

  #output json file
  FileUtils.mkdir_p("#{OUTPUT_DIR}")
  FileUtils.mkdir_p("#{OUTPUT_SOLR_DIR}")
  output_file  = "#{OUTPUT_DIR}/#{stanza_name}.jsonld"
  output_solr_file  = "#{OUTPUT_SOLR_DIR}/#{stanza_name}.json"

  solr_index_file = File.open("#{output_solr_file}", 'w')
  File.open("#{output_file}", 'w') do |file|
    file.puts '{'
    file.puts '"@context" :'
    file.puts JSON.pretty_generate(get_context_hash(stanza_name, columns))
    file.puts ','
    file.puts '"@graph" :'
    file.puts '['
    solr_index_file.puts '['
    comma = ','
    cnt = 0
    result_hash.each do |key, value|
      if cnt == result_hash.size - 1
        comma = ''
      end

      file.puts JSON.pretty_generate(value) + comma
      solr_index_file.puts JSON.pretty_generate(value) + comma
      cnt += 1
    end
    file.puts ']'
    solr_index_file.puts ']'
    file.puts '}'
  end
  solr_index_file.close()
end

@metadata["stanzas"].map do |stanza|
  query_names = []
  stanza["queries"].each do |query|
    query(query["query_name"])
    query_names.push(query["query_name"])
  end
  create_json(stanza["stanza_name"], query_names);
end
