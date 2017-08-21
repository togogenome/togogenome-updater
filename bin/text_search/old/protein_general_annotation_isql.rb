#!/usr/bin/env ruby

require 'httpclient'
require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'
require "../sparql.rb"
require "../sparql_odbc.rb"

start_time = Time.now

base_dir = File.dirname(__FILE__)
endpoint = SPARQL.new("http://ep.dbcls.jp/sparql-import")
sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba") #prevent from timeout exec query with odbc/isql
#template = File.read("#{base_dir}/sparql/gene_attributes_text.erb")
cnt = 0
File.open('gene_list.txt') do |f|
  f.each_line do |line|
    template = File.read("#{base_dir}/sparql/protein_general_annotation_text.erb")
    feature_uri = line
    query_text = ERB.new(template).result(binding)
    result = sparql_odbc.query(query_text)
    result.each do |entry|
      puts entry[:name]
      puts entry[:message]
    end

    cnt += 1
    if (cnt % 100 == 0)
      STDERR.puts (cnt / 100).to_s
    end
    break if (cnt / 1000) > 0 
    #break if cnt > 1 
  end
  sparql_odbc.disconnect()
end

times = "Time: #{Time.now - start_time}s"
STDERR.puts times
