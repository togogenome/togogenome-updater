#!/usr/bin/env ruby

require '/data/store/rdf/togogenome/bin/sparql.rb'
require 'json'
require 'fileutils'

base_dir = File.dirname(__FILE__)
output_dir = "refseq/current/prokaryotes.gb"
endpoint = SPARQL.new(ARGV.shift)

seq_qry = "#{base_dir}/sparql/get_refseq_retry.rq"
seq_lst = ""
endpoint.query(File.read(seq_qry), :format => 'json') do |json|
  seq_lst += json
end
seq_json = JSON.parse(seq_lst)
seq_body = seq_json["results"]["bindings"]

seq_body.map do |seq|
  tax_id = seq['tax_id']['value']
  prj_id = seq['bioproject_accession']['value']
  replicon_type = seq['replicon_type']['value']

  #ignore any human genome projects that aren't GCR project.
  next if tax_id == "9606" && prj_id != "PRJNA168"

  if !(File.exist?("#{output_dir}/#{tax_id}/#{prj_id}")) then
    FileUtils.mkdir_p("#{output_dir}/#{tax_id}/#{prj_id}")
  end
  Dir.chdir("#{output_dir}/#{tax_id}/#{prj_id}") {
    seq_id = seq['seq_id']['value']
    # get sequence id which conforms to a id pattern of http://identifiers.org/refseq/
    if (seq_id =~ /^((AC|AP|NC|NG|NM|NP|NR|NT|NW|XM|XP|XR|YP|ZP)_\d+|(NZ\_[A-Z]{4}\d+))(\.\d+)?$/)
      seq_id = seq_id.split('.').first
      if replicon_type == "Chromosome"
        if !(File.exist?("#{seq_id}")) then
          puts "wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}" if $DEBUG
    #      system("curl http://togows.dbcls.jp/entry/nucleotide/#{seq_id}?clear") unless $DEBUG
          system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
        end
      else # expect Chromosome
        subdir = replicon_type.gsub(" ", "_")
        if !(File.exist?("#{subdir}")) then
          FileUtils.mkdir_p("#{subdir}")
        end
        if !(File.exist?("#{subdir}/#{seq_id}")) then
          puts "wget -P #{subdir} http://togows.dbcls.jp/entry/nucleotide/#{seq_id}" if $DEBUG
    #      system("curl http://togows.dbcls.jp/entry/nucleotide/#{seq_id}?clear") unless $DEBUG
          system("wget -P #{subdir} http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
        end
      end 
    end 
  }
end
