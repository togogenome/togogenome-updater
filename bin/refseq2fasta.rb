#!/usr/bin/env ruby

require 'rubygems'
require 'bio'

Dir.glob("refseq/current/refseq.gb/**/*").each do |file|
  next if File.directory?(file)
  next if file[/.txt$/]

  path = file.split('/')

  tax = path[-3]
  prj = path[-2]
  ent = path[-1]

  Bio::FlatFile.auto(file).each do |entry|
    prefix = "refseq/current/refseq.ttl/#{tax}/#{prj}/#{ent}"
    next unless File.exists?("#{prefix}.ttl")
    File.open("#{prefix}.fasta", "w") do |output|
      desc = %Q[refseq:#{entry.acc_version} {"definition":"#{entry.definition}", "taxonomy":"#{tax}", "bioproject":"#{prj}", "refseq":"#{entry.acc_version}"}]
      $stderr.puts desc
      output.puts entry.seq.to_fasta(desc, 50)
      puts entry.seq.to_fasta(desc, 50)
    end
  end
end
