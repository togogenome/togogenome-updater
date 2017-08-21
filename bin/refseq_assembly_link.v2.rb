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
  puts file
  #system(%Q[grep Assembly #{file} > "/data/store/rdf/togogenome/refseq/current/test_link_ass.txt"])
  system(%Q[grep "Assembly:" #{file}])
end
