#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql.rb"
require 'json'
require 'fileutils'
require 'erb'

endpoint = SPARQL.new(ARGV.shift)
result_list = []
query_kingdom_list = [
  {tax_id: "2", type_material: "AND (?relation_to_type_material  != 'na')"},
  {tax_id: "2157", type_material: "AND (?relation_to_type_material  != 'na')"},
  {tax_id: "10239", type_material: "AND (?relation_to_type_material  != 'na')"},
  {tax_id: "2759", type_material: ""},
]
query_kingdom_list.each do |kingdom|
  tax_id = kingdom[:tax_id]
  type_material = kingdom[:type_material]
  template = File.read("#{base_dir}/sparql/get_refseq_list.erb")
  sparql = ERB.new(template).result(binding)
  result = ""

  endpoint.query(sparql, :format => 'json') do |json|
    result += json
  end

  results = JSON.parse(result)["results"]["bindings"]
  result_list.concat(results)
end
list = result_list.map do |entry|
  hash = {
          :assembly_accession => entry['assembly_accession']['value'],
          :tax_id => entry['tax_id']['value'],
          :bioproject_id => entry['bioproject_accession']['value'],
          :refseq_category => entry['refseq_category']['value'],
          :release_date => entry['release_date']['value'],
          :molecule_name => entry['replicon_type']['value'],
          :refseq_id => entry['seq_id']['value'],
          :relation_to_type_material => entry['relation_to_type_material']['value']
         }
end

puts JSON.pretty_generate(list)
