#!/usr/bin/env ruby

require 'rubygems'
require 'uri'
require 'bio'
require 'json'
require 'securerandom'

# [TODO] integrate this into BioRuby
module Bio
  class GenBank
    def dblink
      fetch('DBLINK')
    end

    def bioproject
      dblink[/\d+/]
    end
  end
end

Bio::FlatFile.auto(ARGF).each do |entry|
  puts [entry.entry_id, entry.bioproject, entry.dblink]
end

