#!/usr/bin/env ruby

require 'json'
require 'fileutils'

TOGO_DIR = '/data/store/rdf/togogenome'
BASE_DIR = "#{TOGO_DIR}/bin/text_search"
DATA_DIR = "#{TOGO_DIR}/text_search/current"
#CORE_DIR = "#{TOGO_DIR}/text_search/solr_cores"
#SOLR_SERVER = 'http://localhost:15963/solr'
CORE_DIR = "#{TOGO_DIR}/text_search/solr_cores_dev"
SOLR_SERVER = 'http://localhost:15963/solr'
SOLR_PARAM = '&stream.contentType=application/json&commit=true'

def load_solr (category)
  if category == "gene"
    metadata = JSON.parse(File.read("#{BASE_DIR}/#{category}.json"))
    metadata["stanzas"].each do |stanza|
      stanza_name = stanza["stanza_name"]
      STDERR.puts "Start: load_solr [#{stanza_name}]"
      STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
      puts "start load to solr. stanza:[#{stanza_name}]"
      file_list = file_name_list("#{DATA_DIR}/#{category}/solr/#{stanza_name}/") 
      file_list.each do |file|
        command = "#{SOLR_SERVER}/#{stanza_name}/update?stream.file=#{file}#{SOLR_PARAM}"
        system(%Q[curl '#{command}'])
      end
      STDERR.puts "End: load_solr [#{stanza_name}]"
      STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
    end
  else
    metadata = JSON.parse(File.read("#{BASE_DIR}/#{category}.json"))
    metadata["stanzas"].each do |stanza|
      stanza_name = stanza["stanza_name"]
      STDERR.puts "Start: load_solr [#{stanza_name}]"
      STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
      command = "#{SOLR_SERVER}/#{stanza_name}/update?stream.file=#{DATA_DIR}/#{category}/solr/#{stanza_name}.json#{SOLR_PARAM}"
      system(%Q[curl '#{command}'])
      STDERR.puts "End: load_solr [#{stanza_name}]"
      STDERR.puts Time.now.strftime("%Y/%m/%d %H:%M:%S")
    end
  end
end

def file_name_list(path)
  file_list = []
  Dir::glob( path + "/*" ).each {|fname|
   if FileTest.file?( fname ) 
     file_list.push(fname)
   end
  }
  file_list
end

load_solr('environment')
load_solr('organism')
load_solr('gene')
