#!/usr/bin/env ruby

require 'json'
require 'fileutils'

ISQL = '/data/store/virtuoso7.1/bin/isql 20711 dba dba'
ISQL_OPT = 'VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stderr'
TOGO_DIR = '/data/store/rdf/togogenome/'
BASE_DIR = "#{TOGO_DIR}/bin/text_search"
PREPARE_DIR = "#{TOGO_DIR}/text_search/current/prepare/gene"
OUTPUT_DIR = "#{TOGO_DIR}/text_search/current/gene"
OUTPUT_SOLR_DIR = "#{OUTPUT_DIR}/solr"
TOGO_UP_JSON = "#{PREPARE_DIR}/json/protein_gene.json"

@metadata = JSON.parse(File.read("#{BASE_DIR}/gene.json"))

def query(query_name)
  STDERR.puts "Start: query [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
  query_file = "#{BASE_DIR}/sparql/gene/#{query_name}.rq"
  FileUtils.mkdir_p("#{PREPARE_DIR}/text")
  output_file = "#{PREPARE_DIR}/text/#{query_name}.txt"
  system(%Q[#{ISQL} #{ISQL_OPT} < #{query_file} > #{output_file}])
  STDERR.puts "End: query [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
end

def create_prepare_json(stanza_name, query_name)
  STDERR.puts "Start: create prepare json [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
  input_file = "#{PREPARE_DIR}/text/#{query_name}.txt"
  FileUtils.mkdir_p("#{PREPARE_DIR}/json")
  output_file  = File.open("#{PREPARE_DIR}/json/#{query_name}.json", 'w')
  output_file.puts '{'
  comma = ','
  cnt = 0
  line_size = 0 
  File.open("#{input_file}") do |f|
    while f.gets; end
    line_size = f.lineno
  end
  STDERR.puts line_size 
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
  File.open("#{input_file}") do |f|
    columns_info = get_query_columns(stanza_name, query_name)
    while line  = f.gets
      result = {}
      if query_name.start_with?('gene')
        text_data = gene_obj_mapping(line, query_name, columns_info)
        id = text_data["gene_id"]
      elsif query_name.start_with?('protein')
        text_data = protein_obj_mapping(line, query_name, columns_info)
        id = text_data["uniprot_id"]
      end
      result[id] = text_data
      json_obj = JSON.pretty_generate(result)
      if cnt == line_size - 1
        comma = ''
      end
      output_file.puts json_obj[2..(json_obj.length - 3)] + comma 
      cnt += 1
    end
    output_file.puts '}'
    #output_file.puts JSON.pretty_generate(result)
  end
  STDERR.puts "End: create prepare json [#{query_name}]"
  STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
end

def create_json (stanza_name,query_names)
  STDERR.puts "Start: create json [#{stanza_name}]"
  if stanza_name.start_with?('gene')
    result_hash = create_idx_from_gene(stanza_name,query_names)
  elsif stanza_name.start_with?('protein')
    result_hash = create_idx_from_protein(stanza_name,query_names)
  end
  output_json(stanza_name, result_hash)

  STDERR.puts "End: create json [#{stanza_name}]"
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
      values["gene_id"] = to_utf(gene_no)
    else # expect id columns are
      value = columns[column["column_number"]].split("|||").map do |entry| to_utf(entry.strip) end
      values[column["column_name"]] = value
    end
  end
  values
end

# convert a hash object from 1 line text data
def protein_obj_mapping(line, query_name, columns_info)
  return line.start_with?('http://purl.uniprot.org/uniprot/') unless
  line.force_encoding('UTF-8')
  line = line.encode("UTF-16BE", "UTF-8", :invalid => :replace, :undef => :replace, :replace => '?').encode("UTF-8")
  columns = line.split('^@')
  values = {}
  columns_info.each do |column|
    if column["is_identify"]
      uniprot_no = columns[column["column_number"]].strip.gsub('http://purl.uniprot.org/uniprot/','')
      values["uniprot_id"] = to_utf(uniprot_no)
    else # expect id columns are
      value = columns[column["column_number"]].split("|||").map do |entry|
        # irregular case
        if query_name == 'protein_cross_references' && column["column_name"] == 'up_xref_ids'
          to_utf(entry.strip.split('/').last)
        elsif query_name == 'protein_sequence_annotation' && column["column_name"] == 'up_seq_anno_feature_ids'
          to_utf(entry.strip.strip.gsub('http://purl.uniprot.org/annotation/',''))
        else
          to_utf(entry.strip)
        end 
      end
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

def create_idx_from_gene (stanza_name, query_names)
  if @gene_up_map == nil
    @gene_up_map = JSON.parse(File.read("#{TOGO_UP_JSON}"))
    STDERR.puts('End: create gene up map')
    gene_id_list = []
    @gene_up_map.each do |protein_id, gene_ids|
      gene_id_list.concat(gene_ids)
    end
    STDERR.puts('End: create gene id list')
  end
  
  result = {}
  query_names.each do |query_name|
    gene_data = JSON.parse(File.read("#{PREPARE_DIR}/json/#{query_name}.json"))
    STDERR.puts("End: loaded gene data [#{query_name}]")
    gene_id_list.each do |gene_id|
      next if gene_data[gene_id].nil? # skip if query data has no current gene id
      if result[gene_id] == nil
        result[gene_id] = gene_data[gene_id]
      else # current gene id has already added gene value
        result[gene_id].merge!(gene_data[gene_id]) do |key, oldval, newval|
          if key == 'gene_id' || key.to_s == '@id' # no repeat of id
            oldval
          else # concat text data
            oldval.concat(newval).uniq 
          end
        end
      end
      gene_data.delete(gene_id)
    end
    STDERR.puts("End: create index data [#{query_name}]")
  end
  result
end

def create_idx_from_protein (stanza_name, query_names)
  if @gene_up_map == nil
    @gene_up_map = JSON.parse(File.read("#{TOGO_UP_JSON}"))
  end
  gene_id_list = @gene_up_map.keys
  result = {}
  query_names.each do |query_name|
    up_data = JSON.parse(File.read("#{PREPARE_DIR}/json/#{query_name}.json"))
    STDERR.puts("End: loaded protein data [#{query_name}]")
 #   gene_id_list.each do |gene_id|
    @gene_up_map.each do |uniprot_id, gene_ids| # protein id has linked multi gene id
      next if up_data[uniprot_id].nil? # skip if query data has no current uniprot id
      gene_ids.each do |gene_id|
        if result[gene_id] == nil
          up_data[uniprot_id]["gene_id"] = gene_id
          up_data[uniprot_id]["@id"] = "http://togogenome.org/gene/#{gene_id}"
          result[gene_id] = up_data[uniprot_id]
        else # current gene id has already added protein value
          result[gene_id].merge!(up_data[uniprot_id]) do |key, oldval, newval|
            if key == 'uniprot_id' # prevent duplicate of uniprot id
              oldval
            else # concat text data
              oldval.concat(newval).uniq 
            end
          end
        end
        up_data.delete(uniprot_id)
      end
    end
    STDERR.puts("End: create index data [#{query_name}]")
  end
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

#query('protein_cross_references')
#query('protein_references')
#create_prepare_json('protein_cross_references', 'protein_cross_references')
#create_json('protein_cross_references', ['protein_cross_references']);
#exit(0)
@metadata["stanzas"].each do |stanza|
  query_names = []
  stanza["queries"].each do |query|
    query(query["query_name"])
#    create_prepare_json(stanza["stanza_name"],query["query_name"])
#    query_names.push(query["query_name"])
  end
#  create_json(stanza["stanza_name"], query_names);
end

