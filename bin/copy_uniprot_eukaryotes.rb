#!/usr/bin/env ruby

require 'fileutils'

list_file = "genomes/current/GENOME_REPORTS/eukaryotes.txt"
orig_dir = ARGV.shift || '../uniprot/current/uniprot_taxon.ttl'
copy_dir = ARGV.shift || 'uniprot/current/eukaryotes'

unless File.directory?(copy_dir)
  FileUtils.mkdir_p(copy_dir)
end

taxids = []
File.open(list_file).each do |line|
  if line[/\tChromosomes\t/]
    taxids << line.split(/\t/)[1].to_i
  end
end

taxids.sort.uniq.each do |taxid|
  taxdir = (taxid / 1000) * 1000
  $stderr.puts taxid
  orig_file = "#{orig_dir}/#{taxdir}/#{taxid}.ttl"
  if File.exists?(orig_file)
    FileUtils.cp(orig_file, copy_dir)
  else
    $stderr.puts "Warning: missing #{orig_file} ..."
    puts "Warning: missing #{orig_file} ..."
  end
end

