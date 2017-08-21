#!/usr/bin/env ruby

require 'json'
require 'yaml'

tax = {}
up = {}
rs = {}

#tax = YAML.load(File.read("bin/taxon_summary/tax.json"))
#up = YAML.load(File.read("bin/taxon_summary/up.json"))
#rs = YAML.load(File.read("bin/taxon_summary/rs.json"))

Dir.glob("uniprot/20130403/prokaryotes/*.ttl").sort.each do |file|
  taxid = File.basename(file).to_i
  tax[taxid] = true
  count = 0
  $stderr.puts "Processing #{file} ..."
  File.open(file).each do |line|
    count += 1 if line[/a :Protein/]
  end
  up[taxid] = count
end

File.open("bin/taxon_summary/up.json", "w") do |file|
  file.puts up.to_json
end

Dir.glob("refseq/prokaryotes.ttl/*/*").sort.each do |dir|
  ary = dir.split('/')
  taxid = ary[2].to_i
  prjid = ary[3]
  tax[taxid] = true
  count = 0
  gene = 0
  cds = 0
  Dir.glob("#{dir}/**/*.ttl").sort.each do |file|
    $stderr.puts "Processing #{file} ..."
    File.open(file).each do |line|
      gene += 1 if line[/obo:SO_0000704/]
      cds += 1 if line[/obo:SO_0000316/]
    end
  end
  rs[taxid] ||= {}
  rs[taxid][prjid] = {:gene => gene, :cds => cds}
  rs[taxid][:gene] ||= 0
  rs[taxid][:gene] += gene
  rs[taxid][:cds] ||= 0
  rs[taxid][:cds] += cds
end

File.open("bin/taxon_summary/rs.json", "w") do |file|
  file.puts rs.to_json
end

File.open("bin/taxon_summary/tax.json", "w") do |file|
  file.puts tax.to_json
end


puts %w(Taxonomy#ID UniProt#protein RefSeq#gene RefSeq#cds BioProject#ID BioProject#gene BioProject#cds).join("\t")
tax.sort.each do |taxid, v|
  if rs[taxid]
    rs[taxid].sort_by{|k,v| k.to_s}.each do |prjid, hash|
      next if prjid.to_s == "gene" or prjid.to_s == "cds"
      puts [
        taxid,
        up[taxid],
        rs[taxid][:gene],
        rs[taxid][:cds],
        prjid,
        hash[:gene],
        hash[:cds]
      ].join("\t")
    end
  else
      puts [
        taxid,
        up[taxid],
        "",
        "",
        "",
        "",
        "",
      ].join("\t")
  end
end
