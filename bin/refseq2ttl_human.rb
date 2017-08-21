#!/usr/bin/env ruby

require 'fileutils'

input_dir = "refseq/current/human.gb"
output_dir = "refseq/current/human.ttl"
output_all = "refseq/current/human.turtle"
refseq2ttl = "bin/refseq2ttl.rb"

system(%Q[ruby #{refseq2ttl} -p > #{output_all}])

org = "Homo sapiens"
tax = "9606"
prj = "PRJNA168"

Dir.glob("#{input_dir}/#{tax}/#{prj}/*").each do |input_file|
  output_file = input_file.sub(input_dir, output_dir).sub(/$/, '.ttl')
  puts ">>> #{output_file} (#{org})"
  $stderr.puts ">>> #{output_file} (#{org})"
  FileUtils.mkdir_p("#{output_dir}/#{tax}/#{prj}")
  system(%Q[ruby #{refseq2ttl} -t "SO:chromosome" #{input_file} > #{output_file}])
  system(%Q[grep -v '^@prefix' #{output_file} >> #{output_all}])
end

prj = "PRJNA30353"

Dir.glob("#{input_dir}/#{tax}/#{prj}/*").each do |input_file|
  output_file = input_file.sub(input_dir, output_dir).sub(/$/, '.ttl')
  puts ">>> #{output_file} (#{org})"
  $stderr.puts ">>> #{output_file} (#{org})"
  FileUtils.mkdir_p("#{output_dir}/#{tax}/#{prj}")
  system(%Q[ruby #{refseq2ttl} -t "SO:mitochondrial_chromosome" #{input_file} > #{output_file}])
  system(%Q[grep -v '^@prefix' #{output_file} >> #{output_all}])
end
