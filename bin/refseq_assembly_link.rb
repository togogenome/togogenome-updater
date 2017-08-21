#!/usr/bin/env ruby

require 'json'
require 'fileutils'


if ARGV.size < 1
 puts "./create_assembly_ttl.rb <refseq_list_json> <output_file>"
 exit(1)
end

refseq_json = ARGV[0]
#output_file = ARGV[1]

refseq_list = open("#{refseq_json}") do |io|
  JSON.load(io)
end

puts "@prefix rdfs:   <http://www.w3.org/2000/01/rdf-schema#> ."
puts "@prefix ass:  <http://ddbj.nig.ac.jp/ontologies/assembly/> ."
puts

refseq_list.each do |seq|
  #puts "<http://identifiers.org/refseq/" + seq["refseq_id"] + "> rdfs:seeAlso <http://www.ncbi.nlm.nih.gov/assembly/" + seq["assembly_accession"] + "> ."
  puts "<http://identifiers.org/refseq/" + seq["refseq_id"] + "> rdfs:seeAlso ass:#{seq["assembly_accession"]} ."
end
