#!/usr/bin/env ruby

require 'json'
require 'fileutils'

TOGO_DIR = '/data/store/rdf/togogenome'
BASE_DIR = "#{TOGO_DIR}/bin/text_search"
INPUT_DIR = "#{TOGO_DIR}/text_search/current/environment"
OUTPUT_DIR = "#{TOGO_DIR}/text_search/current/environment/elastic"

def create_idx(stanza_name)
  input_file = "#{INPUT_DIR}/#{stanza_name}.json"
  text_list = JSON.parse(File.read("#{input_file}"))
  FileUtils.mkdir_p("#{OUTPUT_DIR}")
  output_file  = "#{OUTPUT_DIR}/#{stanza_name}.json"
  output = File.open("#{output_file}", 'w')
  text_list.each{|data|
    id_info = {"_index" => "environment", "_type" => stanza_name, "id" => data["@id"] } 
    command_hash = { "index" => id_info }
    output.puts JSON.generate(command_hash) 
    output.puts JSON.generate(data["values"]) 
  }
end

create_idx('environment_attributes')
create_idx('environment_inhabitants')
