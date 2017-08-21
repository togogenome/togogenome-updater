#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require "./sparql_odbc.rb"

start_time = Time.now

base_dir = File.dirname(__FILE__)
sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba") #prevent from timeout exec query with odbc/isql

query_text = File.read("#{base_dir}/sparql/protein_ontologies_keyword.rq")
result_hash = sparql_odbc.query(query_text, SPARQL_ODBC::PROTEIN_ONTOLOGIES_KEYWORDS)
puts JSON.pretty_generate(result_hash)

times = "Time: #{Time.now - start_time}s"
STDERR.puts times
#Time: 4942.076930895s(1.5h) 
