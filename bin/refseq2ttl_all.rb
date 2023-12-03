#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'parallel'

work_dir = ARGV.shift
input_dir = "#{work_dir}/refseq.gb"
output_dir = "#{work_dir}/refseq.ttl"
output_all = "#{work_dir}/all.turtle"
refseq2ttl = "/rdfsummit/insdc2ttl/insdc2ttl.rb"

# 全件turtleの出力
system(%Q[ruby #{refseq2ttl} -p > #{output_all}])

refseq_list = open("#{work_dir}/refseq_list.json") do |io|
  JSON.load(io)
end

# 各GenBankファイルをturtleに変換
Parallel.each(refseq_list, in_processes: 4) do |entry|
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
  end
end
