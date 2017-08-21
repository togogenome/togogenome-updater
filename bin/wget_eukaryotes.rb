#!/usr/bin/env ruby

require 'fileutils'

genomes_file = "../genomes/20140716/GENOME_REPORTS/eukaryotes.txt"
output_dir = "refseq/current/eukaryotes.gb"

desc = [
  "#  0 Organism/Name",
  "#  1 TaxID",
  "#  2 BioProject Accession",
  "#  3 BioProject ID",
  "#  4 Group",
  "#  5 SubGroup",
  "#  6 Size (Mb)",
  "#  7 GC%",
  "#  8 Assembly Accession",
  "#  9 Chromosomes",
  "# 10 Organelles",
  "# 11 Plasmids",
  "# 12 WGS",
  "# 13 Scaffolds",
  "# 14 Genes",
  "# 15 Proteins",
  "# 16 Release Date",
  "# 17 Modify Date",
  "# 18 Status",
  "# 19 Center",
  "# 20 BioSample Accession",
]

File.open(genomes_file).each do |line|
  next if line[/^#/]

  ary = line.strip.split("\t")

  #next unless (/Complete Genome/.match(ary[18])) || (/Chromosome/.match(ary[18]))
  next unless /Complete Genome|Chromosome/.match(ary[18])

  org = ary[0]
  tax = ary[1]
  prj = ary[2]
  acc = ary[8]
  sta = ary[18]
  puts "#{tax} #{prj} #{acc}" 
=begin
  FileUtils.mkdir_p("#{output_dir}/#{tax}/#{prj}")
  Dir.chdir("#{output_dir}/#{tax}/#{prj}") {
    File.open("genome_report.txt", "w") do |file|
      desc.zip(ary).each do |pair|
        file.puts pair.join("\t")
      end
    end
    puts "In #{output_dir}/#{tax}/#{prj} processing #{org} ..."
    chrs = ary[8].split(',')
    chrs.each do |chr|
      next if chr == '-'
      seq = chr.split('.').first
      puts "wget http://togows.dbcls.jp/entry/nucleotide/#{seq}"
      system("curl http://togows.dbcls.jp/entry/nucleotide/#{seq}?clear")
      system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq}") unless $DEBUG
    end
    pmds = ary[10].split(',')
    unless pmds.first == '-'
      FileUtils.mkdir_p("plasmids")
      Dir.chdir("plasmids") {
        puts "In #{output_dir}/#{tax}/#{prj}/plasmids"
        pmds.each do |pmd|
          next if pmd == '-'
          seq = pmd.split('.').first
          puts "wget http://togows.dbcls.jp/entry/nucleotide/#{seq}"
          system("curl http://togows.dbcls.jp/entry/nucleotide/#{seq}?clear") unless $DEBUG
          system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq}") unless $DEBUG
        end
      }
    end
  }
=end
end

