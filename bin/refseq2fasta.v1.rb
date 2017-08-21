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
    desc = %Q[#{entry.definition} {taxonomy:"#{tax}", bioproject:"#{prj}", refseq:"#{entry.acc_version}"}]
    $stderr.puts desc
    puts entry.seq.to_fasta(desc, 50)
  end
end


