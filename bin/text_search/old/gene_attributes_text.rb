#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require 'httpclient'
require 'json'
require 'erb'
require 'fileutils'
require 'tempfile'
require "../sparql.rb"
require "../sparql_odbc.rb"

   template = File.read("#{base_dir}/sparql/gene_attributes_text.erb") 
   offset = 1800000 
   limit = 10000
   query_text = ERB.new(template).result(binding)
   sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba") #prevent from timeout exec query with odbc/isql
   result = sparql_odbc.query(query_text)
   result.each do |entry|
     puts entry[:feature_uri]
     puts entry[:locus_tag]
     puts entry[:gene_name]
     puts entry[:seq_label]
     puts entry[:refseq_label]
     puts entry[:organism]
   end
