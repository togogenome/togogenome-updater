#!/usr/bin/env ruby

require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'
require 'systemu'

ISQL = '/data/store/virtuoso7.1/bin/isql 20711 dba dba'
ISQL_OPT = 'VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stderr'
TOGO_DIR = '/data/store/rdf/togogenome'
BASE_DIR = "#{TOGO_DIR}/bin/text_search"
PREPARE_DIR = "#{TOGO_DIR}/text_search/current/prepare/phenotype"
OUTPUT_DIR = "#{TOGO_DIR}/text_search/current/phenotype"
OUTPUT_SOLR_DIR = "#{OUTPUT_DIR}/solr"
MPO_JSON = "#{PREPARE_DIR}/json/mpo_id_list.json"

@metadata = JSON.parse(File.read("#{BASE_DIR}/phenotype.json"))

# create mpo_id list
def create_mpo_id_list
  FileUtils.mkdir_p("#{PREPARE_DIR}/json")
  FileUtils.mkdir_p("#{PREPARE_DIR}/text")

  sparql_path = "#{BASE_DIR}/sparql/phenotype/create_mpo_id_list.rq"
  output_path = "#{PREPARE_DIR}/text/mpo_id_list.txt"
  system(%Q[#{ISQL} #{ISQL_OPT} < #{sparql_path} > #{output_path}])
  result_array = []
  File.read(output_path).lines do |line|
    result_array.push(line.chomp.strip)
  end
  File.open("#{MPO_JSON}", 'w') do |file|
    file.puts JSON.pretty_generate(result_array)
  end
end

def query(query_name, mpo_json)
  STDERR.puts "Start: query [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")

  mpo_list = JSON.parse(File.read("#{mpo_json}"))
  temp_query_file = "#{BASE_DIR}/sparql/phenotype/temp_sparql_#{query_name}.rq"
  mpo_list.each do |mpo|
    File.open("#{temp_query_file}", "w") do |f|
      f.puts "set result_timeout = 18000000;"
      f.puts ERB.new(File.read("#{BASE_DIR}/sparql/phenotype/#{query_name}.rq.erb")).result(binding)
    end

    FileUtils.mkdir_p("#{PREPARE_DIR}/text/#{query_name}")
    mpo_id = mpo.split("#").last
    output_file = "#{PREPARE_DIR}/text/#{query_name}/#{mpo_id}.txt"

    # prevent freeze with no reply isql
    max_attempts = 3 #retry count
    num_attempts = 0
    begin
      num_attempts += 1
      sql_command = %Q[#{ISQL} #{ISQL_OPT} < #{temp_query_file} > #{output_file}]
      status, stdout, stderr = systemu sql_command
      raise if stderr.include?("Error") # maybe timeout
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

def create_json (stanza_name,query_names, mpo_json)
  STDERR.puts "Start: create json [#{stanza_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
  mpo_list = JSON.parse(File.read("#{mpo_json}"))
  mpo_list.each do |mpo|
    mpo_id = mpo.split("#").last
    result_hash = text2hash(stanza_name,query_names, mpo_id)
    if result_hash.size > 0
      output_json(stanza_name, result_hash, mpo_id)
    end
  end
  STDERR.puts "End: create json [#{stanza_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
end

# convert a hash object from 1 line text data
def phenotype_obj_mapping(line, query_name, columns_info)
  return line.start_with?('http://purl.jp/bio/01/mpo#') unless
  line.force_encoding('UTF-8')
  line = line.encode("UTF-16BE", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '?').encode("UTF-8")
  columns = line.split('^@')
  values = {}
  columns_info.each do |column|
    if column["is_identify"]
      mpo_no = columns[column["column_number"]].strip.gsub('http://purl.jp/bio/01/mpo#','')
      values["@id"] = "http://togogenome.org/phenotype/#{mpo_no}"
      values["mpo_id"] = to_utf(mpo_no)
    else # expect id columns are
      value = columns[column["column_number"]].split("|||").map do |entry| to_utf(entry.strip) end
      values[column["column_name"]] = value
    end
  end
  values
end

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
def text2hash (stanza_name,query_names, mpo_id)
  result = {}
  #load each query result file
  query_names.each do |query_name|
    input_file = "#{PREPARE_DIR}/text/#{query_name}/#{mpo_id}.txt"
    File.open("#{input_file}") do |f|
      while line  = f.gets
        # convert a line to hash object
        columns_info = get_query_columns(stanza_name, query_name)
        phenotype_text_data = phenotype_obj_mapping(line, query_name, columns_info)

        mpo_id = phenotype_text_data["mpo_id"]
        if result[mpo_id] == nil
          result[mpo_id] = phenotype_text_data
        else
          result[mpo_id].merge!(phenotype_text_data) do |key, oldval, newval|
            if key.to_s == 'mpo_id' || key.to_s == '@id' # no repeat of tax id
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

def output_json (stanza_name, result_hash, mpo_id)
  #get stanza columns name for jsonld @context data
  columns = get_stanza_column_names(stanza_name)

  #output json file
  FileUtils.mkdir_p("#{OUTPUT_DIR}/#{stanza_name}")
  FileUtils.mkdir_p("#{OUTPUT_SOLR_DIR}/#{stanza_name}")
  output_file  = "#{OUTPUT_DIR}/#{stanza_name}/#{mpo_id}.jsonld"
  output_solr_file  = "#{OUTPUT_SOLR_DIR}/#{stanza_name}/#{mpo_id}.json"

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

create_mpo_id_list()
@metadata["stanzas"].each do |stanza|
  query_names = []
  stanza["queries"].each do |query|
    query(query["query_name"], "#{MPO_JSON}")
    query_names.push(query["query_name"])
  end
  create_json(stanza["stanza_name"], query_names, "#{MPO_JSON}");
end

