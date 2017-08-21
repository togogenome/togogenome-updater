#!/usr/bin/env ruby

require 'fileutils'
require 'json'

#json_file = 'refseq/current/refseq.tax.json'
list_dir = 'refseq/current/refseq.gb'
orig_dir = ARGV.shift || '../uniprot/current/uniprot_taxon.ttl'
copy_dir = ARGV.shift || 'uniprot/current/refseq'

unless File.directory?(copy_dir)
  FileUtils.mkdir_p(copy_dir)
end

#json = JSON.parse(File.read(json_file))
#taxids = (json["list_taxid"] + json["list_taxup"]).sort.uniq.map {|x| x.to_i}
taxids = []
add_tax_file = File.open("refseq/current/add_taxup_list.txt", "r")
while line = add_tax_file.gets
 taxids << line.strip.to_i
end

taxids.sort.each do |taxid|
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

