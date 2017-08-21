#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require "./sparql_odbc.rb"

start_time = Time.now

base_dir = File.dirname(__FILE__)
sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba") #prevent from timeout exec query with odbc/isql

query_text = File.read("#{base_dir}/sparql/protein_names_summary.rq")
result_hash = sparql_odbc.query(query_text, SPARQL_ODBC::PROTEIN_NAMES_SUMMARY)
puts JSON.pretty_generate(result_hash)

times = "Time: #{Time.now - start_time}s"
STDERR.puts times
#Time: 10095.640217739s(3h) query time: 0.5h 
