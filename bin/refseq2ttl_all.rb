#!/usr/bin/env ruby

require 'json'
require 'fileutils'

input_dir = "refseq/current/refseq.gb"
output_dir = "refseq/current/refseq.ttl"
output_all = "refseq/current/all.turtle"
refseq2ttl = "bin/rdfsummit/insdc2ttl/insdc2ttl.rb"

system(%Q[ruby #{refseq2ttl} -p > #{output_all}])

refseq_json = ARGV.shift
refseq_list = open("#{refseq_json}") do |io|
  JSON.load(io)
end

refseq_list.each do |entry|
  tax_id = entry['tax_id']
  prj_id = entry['bioproject_id']
  molecule_name = entry['molecule_name']

  if !(File.exist?("#{output_dir}/#{tax_id}/#{prj_id}")) then
    FileUtils.mkdir_p("#{output_dir}/#{tax_id}/#{prj_id}")
  end

  seq_id = entry['refseq_id']
  input_file = "#{input_dir}/#{tax_id}/#{prj_id}/#{seq_id}"
  output_file = "#{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl"
  next if File.exist?("#{output_file}")
  if (File.exist?("#{input_file}")) then
    puts ">>> #{output_file}"
    $stderr.puts ">>> #{output_file}"
    puts "convert file #{seq_id} ..."
    system(%Q[ruby #{refseq2ttl} -d RefSeq -t "#{molecule_name}" #{input_file} > #{output_file}])
    system(%Q[grep -v '^@prefix' #{output_file} >> #{output_all}])
  end
end
