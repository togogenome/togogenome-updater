#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require "./sparql_odbc.rb"

start_time = Time.now

base_dir = File.dirname(__FILE__)
sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba") #prevent from timeout exec query with odbc/isql

query_text = File.read("#{base_dir}/sparql/protein_sequence_annotation.rq")
result_hash = sparql_odbc.query(query_text, SPARQL_ODBC::PROTEIN_SEQUENCE_ANNOTANION)
puts JSON.pretty_generate(result_hash)

times = "Time: #{Time.now - start_time}s"
STDERR.puts times
#Time: 18889.540168856s(5.5h) query 0.5h-1.0h:
#Time: 17862.843236023s up fetch size
