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

def triple(s, p, o)
  return [s, p, o].join("\t") + " ."
end

refseq2up_file = ARGV.shift
idmapping_file = ARGV.shift
tax_check_file = "refseq/current/refseq.tax.json"

output_tsv = refseq2up_file + '.tsv'
output_ttl = refseq2up_file + '.ttl'

$output_tsv = File.open(output_tsv, "w")
$output_ttl = File.open(output_ttl, "w")

$output_tsv.puts ["# NCBI taxonomy", "BioProject ID", "RefSeq ID", "Feature", "Gene ID", "Protein ID", "UniProt taxonomy", "UniProt ID", "TogoGenome URI", "UniProt URI"].join("\t")

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

$pi = {}

# ~ 4 min
count = 0
count_nc = 0
File.open(refseq2up_file).each do |line|
  taxid, bpid, rsid, feature, gene_id, protein_id = line.strip.split("\t")
  if protein_id
    $pi[protein_id] = line
  else
    $output_tsv.puts line
    # Following entries contains () in their locus_tag ID which are not allowed in the QName format.
    #   togo:138119:DSY_tRNA16-SeC(p)   rdfs:seeAlso    tax:138119 .
    #   togo:138119:DSY_tRNA49-SeC(p)   rdfs:seeAlso    tax:138119 .
    #   togo:882:DVU_tRNA-SeC(p)-1      rdfs:seeAlso    tax:882 .
    #   togo:243275:TDE_tRNA-SeC(p)-1   rdfs:seeAlso    tax:243275 .
    #   togo:221988:MStRNA-SeC(p)-1     rdfs:seeAlso    tax:221988 .
    # $output_ttl.puts triple("togo:#{taxid}:#{locus_tag}", "rdfs:seeAlso", "tax:#{taxid}")
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_id}>", "rdfs:seeAlso", "tax:#{taxid}")
    $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxid_list[taxid]
    $taxid_list[taxid] = true
    count_nc += 1
  end
  count += 1
  #puts "#{count} (#{100.0 * count / 8116958}%)" if count % 100000 == 0
end

def output(pi_list, taxup, up)
  pi_list.each do |pi|
    taxid, bpid, rsid, feature, gene_id, = $pi[pi].split("\t")
    if taxid != taxup
      $tax_mismatch["#{taxid}-#{taxup}"] = true
    end
    $output_tsv.puts [
      taxid,
      bpid,
      rsid,
      feature,
      gene_id,
      pi,
      taxup,
      up,
      "http://togogenome.org/gene/#{taxid}:#{gene_id}",
      "http://identifiers.org/uniprot/#{up}",
    ].join("\t")
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_id}>", "rdfs:seeAlso", "upid:#{up}")
    $output_ttl.puts triple("upid:#{up}", "rdf:type", "<http://identifiers.org/uniprot>")
    $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "up:#{up}")
    $output_ttl.puts triple("up:#{up}", "dct:publisher", "mir:MIR:00100134")  # UniProt (www.uniprot.org)
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_id}>", "rdfs:seeAlso", "tax:#{taxid}")
    $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "tax:#{taxup}")
    $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxid_list[taxid]
    if taxid != taxup
      $output_ttl.puts triple("tax:#{taxup}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxup_list[taxup]
    end
    $taxid_list[taxid] = true
    $taxup_list[taxup] = true
  end
end


up = up_prev = nil
taxup = nil
pi_list = []
pi_done = {}

File.open(idmapping_file).each do |line|
  up, xref, id = line.strip.split(/\s+/)
  case xref
  when "RefSeq"
    if $pi[id]
      pi_list << id
      pi_done[id] = true
    end
  when "NCBI_TaxID"
    taxup = id
  end
  if up != up_prev
    output(pi_list, taxup, up_prev)
    pi_list = []
  end
  up_prev = up
end
output(pi_list, taxup, up_prev)  # ensure the last one

# Coding genes failed to map to UniProt
no_up = $pi.keys - pi_done.keys
no_up.each do |pi|
  taxid, bpid, rsid, feature, gene_id, pi = $pi[pi].strip.split("\t")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_id}>", "rdfs:seeAlso", "tax:#{taxid}")
  $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>")
end

File.open(tax_check_file, "w") do |file|
  file.puts %Q|{
  "count_taxid": #{$taxid_list.keys.size},
  "count_taxup": #{$taxup_list.keys.size},
  "count_tax_mismatch": #{$tax_mismatch.keys.size},
  "list_taxid": [ #{$taxid_list.keys.sort.join(', ')} ],
  "list_taxup": [ #{$taxup_list.keys.sort.join(', ')} ],
  "list_tax_mismatch": #{$tax_mismatch.keys.sort.inspect},
  "count_all_genes": #{count},
  "count_non_coding": #{count_nc},
  "count_no_uniprot": #{no_up.size}
}|
end
