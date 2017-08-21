#!/usr/bin/env ruby
#
# % time ruby bin/refseq2gi-phase2.rb refseq/current/prokaryotes.gi ../uniprot/current/uniprot_unzip/idmapping.dat > refseq/current/prokaryotes.tax
# ruby bin/refseq2gi-phase2.rb refseq/current/prokaryotes.gi  >   12857.00s user 33.91s system 99% cpu 3:36:30.22 total
#

require 'rubygems'
require 'uri'
require 'json'
require 'securerandom'

def triple(s, p, o)
  return [s, p, o].join("\t") + " ."
end

refseq2gi_file = ARGV.shift
idmapping_file = ARGV.shift

output_tsv = refseq2gi_file + '.tsv'
output_ttl = refseq2gi_file + '.ttl'

$output_tsv = File.open(output_tsv, "w")
$output_ttl = File.open(output_ttl, "w")

$output_tsv.puts ["# NCBI taxonomy", "BioProject ID", "RefSeq ID", "Locus tag", "GI", "UniProt taxonomy", "UniProt ID", "TogoGenome URI", "UniProt URI"].join("\t")

$output_ttl.puts triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>")
$output_ttl.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
$output_ttl.puts triple("@prefix", "dct:", "<http://purl.org/dc/terms/>")
$output_ttl.puts triple("@prefix", "togo:", "<http://togogenome.org/gene/>")
$output_ttl.puts triple("@prefix", "upid:", "<http://identifiers.org/uniprot/>")
$output_ttl.puts triple("@prefix", "tax:", "<http://identifiers.org/taxonomy/>")
$output_ttl.puts triple("@prefix", "up:", "<http://purl.uniprot.org/uniprot/>")
$output_ttl.puts triple("@prefix", "mir:", "<http://identifirs.org/miriam.resource/>")
$output_ttl.puts

$taxid_list = {}
$taxup_list = {}
$tax_mismatch = {}

$gi = {}

# ~ 4 min
# count = 0
File.open(refseq2gi_file).each do |line|
  # count += 1
  # puts "#{count} (#{100.0 * count / 8116958}%)" if count % 100000 == 0
  taxid, bpid, rsid, locus_tag, gi = line.strip.split("\t")
  $gi[gi] = line
end

def output(gilist, taxup, up)
  gilist.each do |gi|
    taxid, bpid, rsid, locus_tag, = $gi[gi].split("\t")
    $taxid_list[taxid] = true
    $taxup_list[taxup] = true
    if taxid != taxup
      $tax_mismatch["#{taxid}-#{taxup}"] = true
    end
    $output_tsv.puts [
      taxid,
      bpid,
      rsid,
      locus_tag,
      gi,
      taxup,
      up,
      "http://togogenome.org/gene/#{taxid}:#{locus_tag}",
      "http://identifiers.org/uniprot/#{up}",
    ].join("\t")
    # Need to be URI for avoiding
    #   *** Error 37000: [Virtuoso Driver][Virtuoso Server]SP029:
    #   TURTLE RDF loader, line 59317:
    #   Sequence blank node (written as list in parenthesis)
    #   can not be used as a predicate processed pending to here."
    # e.g., "togo:138119:DSY_tRNA16-SeC(p)   rdfs:seeAlso    tax:138119 ."
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{locus_tag}>", "rdfs:seeAlso", "upid:#{up}")
    $output_ttl.puts triple("upid:#{up}", "rdf:type", "<http://identifiers.org/uniprot>")
    $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "up:#{up}")
    $output_ttl.puts triple("up:#{up}", "dct:publisher", "mir:MIR:00100134")  # UniProt (www.uniprot.org)
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{locus_tag}>", "rdfs:seeAlso", "tax:#{taxid}")
    $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "tax:#{taxup}")
    $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>")
    $output_ttl.puts triple("tax:#{taxup}", "rdf:type", "<http://identifiers.org/taxonomy>") if taxid != taxup
  end
end


up = up_prev = nil
taxup = nil
gilist = []
gidone = {}

File.open(idmapping_file).each do |line|
  up, xref, id = line.strip.split(/\s+/)
  case xref
  when "GI"
    if $gi[id]
      gilist << id
      gidone[id] = true
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
output(gilist, taxup, up)  # ensure the last one

# non-coding genes (or genes failed to map to UniProt)
no_up = $gi.keys - gidone.keys
no_up.each do |gi|
  taxid, bpid, rsid, locus_tag, gi = $gi[gi].strip.split("\t")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{locus_tag}>", "rdfs:seeAlso", "tax:#{taxid}")
  $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>")
end

puts %Q|{
  "taxid_count": #{$taxid_list.keys.size},
  "taxup_count": #{$taxup_list.keys.size},
  "mismatch_count": #{$tax_mismatch.keys.size},
  "taxid_list": [ #{$taxid_list.keys.sort.join(', ')} ],
  "taxup_list": [ #{$taxup_list.keys.sort.join(', ')} ],
  "mismatch": #{$tax_mismatch.keys.sort.inspect}
}|
