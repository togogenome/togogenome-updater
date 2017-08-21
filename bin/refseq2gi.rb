#!/usr/bin/env ruby
#
# % time ruby bin/refseq2gi.rb refseq/release61/prokaryotes.gb > refseq/release61/togogenome2up.ttl 2> refseq/release61/prokaryotes.gi
# ruby bin/refseq2gi.rb refseq/release61/prokaryotes.gb >  2>   6698.02s user 76.28s system 98% cpu 1:54:15.63 total
#

require 'rubygems'
require 'uri'
require 'bio'
require 'json'
require 'securerandom'

def triple(s, p, o)
  return [s, p, o].join("\t") + " ."
end

def output(gilist, taxup, up)
  gilist.each do |gi|
    refseq, taxid, locus_tag, = $tg[gi].split("\t")
    $stderr.puts "http://togogenome.org/gene/#{taxid}:#{locus_tag}\t#{refseq}\t#{gi}\thttp://identifiers.org/uniprot/#{up}\t#{taxid}\t#{locus_tag}\t#{taxup}\t#{up}"
    puts triple("togo:#{taxid}:#{locus_tag}", "rdfs:seeAlso", "upid:#{up}")
    puts triple("upid:#{up}", "rdf:type", "<http://identifiers.org/uniprot>")
    puts triple("togo:#{taxid}:#{locus_tag}", "rdfs:seeAlso", "tax:#{taxid}")
    puts triple("upid:#{up}", "rdfs:seeAlso", "tax:#{taxup}")
    puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>")
    puts triple("tax:#{taxup}", "rdf:type", "<http://identifiers.org/taxonomy>") if taxid != taxup
    puts triple("upid:#{up}", "rdfs:seeAlso", "up:#{up}")
    puts triple("up:#{up}", "dct:publisher", "mir:MIR:00100134")
  end
end

puts triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>")
puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
puts triple("@prefix", "dct:", "<http://purl.org/dc/terms/>")
puts triple("@prefix", "togo:", "<http://togogenome.org/gene/>")
puts triple("@prefix", "upid:", "<http://identifiers.org/uniprot/>")
puts triple("@prefix", "tax:", "<http://identifiers.org/taxonomy/>")
puts triple("@prefix", "up:", "<http://purl.uniprot.org/uniprot/>")
puts triple("@prefix", "mir", "<http://identifirs.org/miriam.resource/>")
puts

$tg = {}
dir = ARGV.shift
count = 0

Dir.glob("#{dir}/**/*").each do |file|
  next if File.directory?(file)
  next if file[/.txt$/]
  Bio::FlatFile.open(file).each do |entry|
    entry = entry
    features = entry.features
    source = features.shift

    if xref = source.to_hash["db_xref"]
      taxid = xref.find{|x| x[/taxon:/]}.split(':', 2).last
      features.each do |feat|
        hash = feat.to_hash
        if hash["locus_tag"]
          if locus_tag = hash["locus_tag"].first
            if hash["db_xref"]
              if gixref = hash["db_xref"].find{|x| x[/GI:/]}
                gi = gixref.split(':', 2).last
                $tg[gi] = "#{entry.entry_id}\t#{taxid}\t#{locus_tag}"
              end
            end
          end
        end
      end
    else
      $stderr.puts "Couldn't find taxid for #{entry.entry_id}" if $DEBUG
    end
  end
end

up = up_prev = nil
taxup = nil
gilist = []

File.open("/data/store/rdf/uniprot/current/uniprot_unzip/idmapping.dat").each do |line|
  up, xref, id = line.strip.split(/\s+/)
  case xref
  when "GI"
    if $tg[id]
      gilist << id
    end
  when "NCBI_TaxID"
    taxup = id
  end
  if up != up_prev
    output(gilist, taxup, up)
    gilist = []
  end
  up_prev = up
end

output(gilist, taxup, up)

