#!/usr/bin/env ruby

require 'fileutils'

list_dir = 'refseq/current/prokaryotes.gb'
orig_dir = ARGV.shift || '../uniprot/current/uniprot_taxon.rdf'
copy_dir = ARGV.shift || 'uniprot/current/prokaryotes'

unless File.directory?(copy_dir)
  FileUtils.mkdir_p(copy_dir)
end

taxids = []
Dir.glob("#{list_dir}/*").each do |file|
  taxids << File.basename(file).to_i
end

taxids.sort.each do |taxid|
  taxdir = (taxid / 1000) * 1000
  $stderr.puts taxid
  orig_file = "#{orig_dir}/#{taxdir}/#{taxid}.rdf"
  if File.exists?(orig_file)
    FileUtils.cp(orig_file, copy_dir)
  else
    $stderr.puts "Warning: missing #{orig_file} ..."
    puts "Warning: missing #{orig_file} ..."
  end
end

