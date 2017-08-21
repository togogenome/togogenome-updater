#!/usr/bin/env ruby

require 'fileutils'

# http://www.ncbi.nlm.nih.gov/bioproject/168
# http://www.ncbi.nlm.nih.gov/assembly/GCF_000001405.25/
# http://www.ncbi.nlm.nih.gov/genome/?term=homo%20sapiens%20mitochondria
# http://www.ncbi.nlm.nih.gov/nuccore/251831106

chromosomes = {
  "Chromosome 1" => "NC_000001.10",
  "Chromosome 2" => "NC_000002.11",
  "Chromosome 3" => "NC_000003.11",
  "Chromosome 4" => "NC_000004.11",
  "Chromosome 5" => "NC_000005.9",
  "Chromosome 6" => "NC_000006.11",
  "Chromosome 7" => "NC_000007.13",
  "Chromosome 8" => "NC_000008.10",
  "Chromosome 9" => "NC_000009.11",
  "Chromosome 10" => "NC_000010.10",
  "Chromosome 11" => "NC_000011.9",
  "Chromosome 12" => "NC_000012.11",
  "Chromosome 13" => "NC_000013.10",
  "Chromosome 14" => "NC_000014.8",
  "Chromosome 15" => "NC_000015.9",
  "Chromosome 16" => "NC_000016.9",
  "Chromosome 17" => "NC_000017.10",
  "Chromosome 18" => "NC_000018.9",
  "Chromosome 19" => "NC_000019.9",
  "Chromosome 20" => "NC_000020.10",
  "Chromosome 21" => "NC_000021.8",
  "Chromosome 22" => "NC_000022.10",
  "Chromosome X" => "NC_000023.10",
  "Chromosome Y" => "NC_000024.9",
  "Mitochondria" => "NC_012920.1",
}

output_dir = "refseq/current/human.gb"

chromosomes.each do |chromosome, chr|
  org = "Homo sapiens"
  tax = "9606"
  if chromosome[/^Chromosome/]
    prj = "PRJNA168"
  else
    prj = "PRJNA30353"
  end
  FileUtils.mkdir_p("#{output_dir}/#{tax}/#{prj}")
  Dir.chdir("#{output_dir}/#{tax}/#{prj}") {
    puts "In #{output_dir}/#{tax}/#{prj} processing #{org} ..."
    seq = chr.split('.').first
    next if File.exists?(seq)
    #puts "wget http://togows.dbcls.jp/entry/nucleotide/#{seq}"
    #system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq}") unless $DEBUG
    puts "wget http://togows.org/entry/nucleotide/#{seq}"
    system("wget http://togows.org/entry/nucleotide/#{seq}") unless $DEBUG
  }
end
