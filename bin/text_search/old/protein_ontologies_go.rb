#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require "./sparql_odbc.rb"

start_time = Time.now

base_dir = File.dirname(__FILE__)
sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba") #prevent from timeout exec query with odbc/isql

query_text = File.read("#{base_dir}/sparql/protein_ontologies_go.rq")
result_hash = sparql_odbc.query(query_text, SPARQL_ODBC::PROTEIN_ONTOLOGIES_GO)
puts JSON.pretty_generate(result_hash)

times = "Time: #{Time.now - start_time}s"
STDERR.puts times
#Time: 4942.076930895s(1.5h)
#Time: 2484.999409376s(40min) up buffer size
