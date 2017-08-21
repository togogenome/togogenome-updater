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

#template = File.read("#{base_dir}/sparql/gene_attributes_text.erb")
cnt = 0
File.open('gene_list.txt') do |f|
  f.each_line do |line|
    template = File.read("#{base_dir}/sparql/protein_general_annotation_text.erb")
    feature_uri = line
    query_text = ERB.new(template).result(binding)

    result = ""
    endpoint.query(query_text, :format => 'json') do |json|
      result += json
    end

    results = JSON.parse(result)["results"]["bindings"]
    results.map do |entry|
      puts entry['name']['value']
      puts entry['message']['value']
    end

    cnt += 1
    if (cnt % 1000 == 0)
      STDERR.puts (cnt / 1000).to_s
    end
    break if (cnt / 1000) > 0 
    #break if cnt > 1 
  end
end

times = "Time: #{Time.now - start_time}s"
STDERR.puts times
