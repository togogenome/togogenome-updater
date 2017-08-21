#!/usr/bin/env ruby

require 'fileutils'

genomes_file = "genomes/current/GENOME_REPORTS/prokaryotes.txt"
input_dir = "refseq/current/prokaryotes.gb"
output_dir = "refseq/current/prokaryotes.ttl"
output_all = "refseq/current/prokaryotes.turtle"
#refseq2ttl = "bin/refseq2ttl.rb"
refseq2ttl = "bin/insdc2ttl/insdc2ttl.rb"

system(%Q[ruby #{refseq2ttl} -p > #{output_all}])

File.open(genomes_file).each do |line|
  next if line[/^#/]

  ary = line.strip.split("\t")

  next unless /Complete( Genome)*/.match(ary[18])
  
  org = ary[0]
  tax = ary[1]
  prj = ary[2]

  chrs = ary[8].split(',')
  pmds = ary[10].split(',')

  chrs.uniq.each_with_index do |chr, i|
    next if chr == '-'
    seq = chr.split('.').first
    puts ">>> #{output_dir}/#{tax}/#{prj}/#{seq}.ttl (#{org})"
    $stderr.puts ">>> #{output_dir}/#{tax}/#{prj}/#{seq}.ttl (#{org})"
    FileUtils.mkdir_p("#{output_dir}/#{tax}/#{prj}")
    system(%Q[ruby #{refseq2ttl} -d RefSeq -t "SO:chromosome" #{input_dir}/#{tax}/#{prj}/#{seq} > #{output_dir}/#{tax}/#{prj}/#{seq}.ttl])
    system(%Q[grep -v '^@prefix' #{output_dir}/#{tax}/#{prj}/#{seq}.ttl >> #{output_all}])
  end

  pmds.uniq.each_with_index do |pmd, i|
    next if pmd == '-'
    seq = pmd.split('.').first
    puts ">>> #{output_dir}/#{tax}/#{prj}/plasmids/#{seq}.ttl (#{org})"
    $stderr.puts ">>> #{output_dir}/#{tax}/#{prj}/plasmids/#{seq}.ttl (#{org})"
    FileUtils.mkdir_p("#{output_dir}/#{tax}/#{prj}/plasmids")
    system(%Q[ruby #{refseq2ttl} -d RefSeq -t "SO:plasmid" #{input_dir}/#{tax}/#{prj}/plasmids/#{seq} > #{output_dir}/#{tax}/#{prj}/plasmids/#{seq}.ttl])
    system(%Q[grep -v '^@prefix' #{output_dir}/#{tax}/#{prj}/plasmids/#{seq}.ttl >> #{output_all}])
  end
end
