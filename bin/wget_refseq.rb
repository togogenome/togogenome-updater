#!/usr/bin/env ruby

require '/data/store/rdf/togogenome/bin/sparql.rb'
require 'json'
require 'fileutils'
require 'erb'

base_dir = File.dirname(__FILE__)
output_dir = "refseq/current/prokaryotes.gb"
endpoint = SPARQL.new(ARGV.shift)

prj_qry = "#{base_dir}/sparql/get_refseq_projects.rq"
prj_lst = ""
endpoint.query(File.read(prj_qry), :format => 'json') do |json|
  prj_lst += json
end
prj_json = JSON.parse(prj_lst)
prj_body = prj_json["results"]["bindings"]

prj_body.map do |prj|
  assy_id = prj['assembly_id']['value']
  tax_id = prj['tax_id']['value']
  prj_id = prj['bioproject_accession']['value']

  #ignore any human genome projects that aren't GCR project.
  next if tax_id == "9606" && prj_id != "PRJNA168"

  FileUtils.mkdir_p("#{output_dir}/#{tax_id}/#{prj_id}")
  template = File.read("#{base_dir}/sparql/get_refseq_sequences.erb")
  seq_qry = ERB.new(template).result(binding)
  seq_lst = ""
  endpoint.query(seq_qry, :format => 'json') do |json|
    seq_lst += json
  end
  Dir.chdir("#{output_dir}/#{tax_id}/#{prj_id}") {
    seq_body = JSON.parse(seq_lst)["results"]["bindings"]
    seq_body.map do |seq|
      replicon_type = seq['replicon_type']['value']
      seq_id = seq['seq_id']['value']
      if (seq_id =~ /^((AC|AP|NC|NG|NM|NP|NR|NT|NW|XM|XP|XR|YP|ZP)_\d+|(NZ\_[A-Z]{4}\d+))(\.\d+)?$/)
        seq_id = seq_id.split('.').first
        system("curl http://togows.dbcls.jp/entry/nucleotide/#{seq_id}?clear") unless $DEBUG
        if replicon_type == "Chromosome"
          puts "wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
          system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
        else
          subdir = replicon_type.gsub(" ", "_")
          FileUtils.mkdir_p("#{subdir}")
          puts "wget -P #{subdir} http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
          system("wget -P #{subdir} http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
        end 
      end 
    end
  }
end
