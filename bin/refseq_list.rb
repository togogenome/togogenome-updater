#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql.rb"
require 'json'
require 'fileutils'

endpoint = SPARQL.new(ARGV.shift)

sparql = "#{base_dir}/sparql/get_refseq_retry.rq"
result = ""

endpoint.query(File.read(sparql), :format => 'json') do |json|
  result += json
end

results = JSON.parse(result)["results"]["bindings"]

list = results.select do |seq|
  if seq['tax_id']['value'] == "9606" && seq['bioproject_accession']['value'] != "PRJNA168"
    #ignore any human genome projects that aren't GCR project.
    false 
  else
    # get sequence ID which conforms to an ID pattern of http://identifiers.org/refseq/
    seq['seq_id']['value'][/^((AC|AP|NC|NG|NM|NP|NR|NT|NW|XM|XP|XR|YP|ZP)_\d+|(NZ\_[A-Z]{4}\d+))(\.\d+)?$/]
  end
end

puts JSON.pretty_generate(list)

