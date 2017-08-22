#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql.rb"
require 'json'
require 'fileutils'

endpoint = SPARQL.new(ARGV.shift)

sparql = "#{base_dir}/sparql/get_refseq_list.rq"
result = ""

endpoint.query(File.read(sparql), :format => 'json') do |json|
  result += json
end

results = JSON.parse(result)["results"]["bindings"]

list = results.map do |entry|
  hash = {
          :assembly_accession => entry['assembly_accession']['value'],
          :tax_id => entry['tax_id']['value'],
          :bioproject_id => entry['bioproject_accession']['value'],
          :refseq_category => entry['refseq_category']['value'],
          :release_date => entry['release_date']['value'],
          :molecule_name => entry['replicon_type']['value'],
          :refseq_id => entry['seq_id']['value']
         }
end

puts JSON.pretty_generate(list)
