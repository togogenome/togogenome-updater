#!/usr/bin/env ruby

@base_dir = File.dirname(__FILE__)

#require "rubygems"
#require "sequel"
require 'erb'
require './sparql_odbc.rb'

sparql_odbc = SPARQL_ODBC.new("VIRT_UP", "dba", "dba")
template = File.read("#{@base_dir}/sparql/create_refseq2up_tsv.rq.erb")
rsid = "NC_000010.11"
sparql = ERB.new(template).result(binding)
start = Time.now
for num in 1..100 do
 result = sparql_odbc.query(sparql)
 result.each {|entry|
         refseq_data = {
        :taxid => entry[:taxonomy_id],
        :bpid => entry[:bioproject_id],
        :rsid => rsid,
        :feature_rsrc => entry[:feature],
        :feature_label => entry[:feature_label],
        :feature_type => entry[:feature_type],
        :gene_rsrc => entry[:gene],
        :gene_label => entry[:gene_label]
      }
      if entry['protein_id']
        refseq_data[:protein_id] = entry[:protein_id]
      else
        refseq_data[:protein_id] = nil
      end   
 }
 fin = Time.now
 time = (fin - start).to_i
 puts num.to_s + "(#{time}):" + result.size.to_s
 start = fin
end
