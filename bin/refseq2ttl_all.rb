#!/usr/bin/env ruby

require 'json'
require 'fileutils'

input_dir = "refseq/current/refseq.gb"
output_dir = "refseq/current/refseq.ttl"
output_all = "refseq/current/all.turtle"
refseq2ttl = "bin/rdfsummit/insdc2ttl/insdc2ttl.rb"

system(%Q[ruby #{refseq2ttl} -p > #{output_all}])

refseq_json = ARGV.shift
#previous_dir = "/data/store/rdf/togogenome/refseq/" + ARGV.shift + "/refseq.ttl" #TODO get previous version from file
refseq_list = open("#{refseq_json}") do |io|
  JSON.load(io)
end

refseq_list.each do |entry|
  tax_id = entry['tax_id']
  prj_id = entry['bioproject_id']
  molecule_name = entry['molecule_name']

  if !(File.exist?("#{output_dir}/#{tax_id}/#{prj_id}")) then
    #puts "mkdir_p #{output_dir}/#{tax_id}/#{prj_id}"
    FileUtils.mkdir_p("#{output_dir}/#{tax_id}/#{prj_id}")
  end

  seq_id = entry['refseq_id']
  input_file = "#{input_dir}/#{tax_id}/#{prj_id}/#{seq_id}"
  output_file = "#{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl"
  next if File.exist?("#{output_file}") # TODO delete
  if (File.exist?("#{input_file}")) then
    puts ">>> #{output_file}"
    $stderr.puts ">>> #{output_file}"
#    puts "#{previous_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl"
#    puts File.exist?("#{previous_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl")
#    if previous_dir != nil && File.exist?("#{previous_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl") then
#      puts "link previous file #{seq_id} ..."
#      system("ln #{previous_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl #{output_file}") unless $DEBUG
#      system(%Q[grep -v '^@prefix' #{output_file} >> #{output_all}])
#    else
      puts "convert file #{seq_id} ..."
      system(%Q[ruby #{refseq2ttl} -d RefSeq -t "#{molecule_name}" #{input_file} > #{output_file}])
      system(%Q[grep -v '^@prefix' #{output_file} >> #{output_all}])
#    end
  end
end
