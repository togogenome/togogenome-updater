#!/usr/bin/env ruby
#
# 2013-11-01 21:13:42 load:0.81 -----
# % ruby bin/refseq2up-phase2.rb refseq/current/prokaryotes.up ../uniprot/current/uniprot_unzip/idmapping.dat > refseq/current/prokaryotes.tax.json
# 2013-11-02 02:14:46 load:3.26 (^-^)
#

require 'rubygems'
require 'uri'
require 'json'
require 'securerandom'

idmapping_file =ARGV.shift
file = File.open(idmapping_file, "r")
cnt = 0
while line = file.gets
  up, xref, id = line.strip.split(/\s+/)
  cnt += 1
  if (cnt % 100000 == 0)
   puts cnt
  end
end
exit(0)
=begin
File.open(idmapping_filei.each do |line|
  up, xref, id = line.strip.split(/\s+/)
  case xref
  when "RefSeq"
    unless $rs_prot_id[id]
      $rs_prot_id[id] = []    
    end
    $rs_prot_id[id] << up
  when "NCBI_TaxID"
    $uptax[up] = id
  end
  cnt += 1
  if (cnt % 100000)
   puts cnt
  end
end
puts $rs_prot_id.size
=end
