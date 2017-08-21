#!/usr/bin/env ruby
#
# 2013-11-01 21:13:42 load:0.81 -----
# % ruby bin/refseq2up-phase2.rb refseq/current/prokaryotes.up ../uniprot/current/uniprot_unzip/idmapping.dat > refseq/current/prokaryotes.tax.json
# 2013-11-02 02:14:46 load:3.26 (^-^)
#

@base_dir = File.dirname(__FILE__)

require 'rubygems'
require 'uri'
require 'json'
require 'erb'
require 'securerandom'
require "./#{@base_dir}/sparql.rb"


def triple(s, p, o)
  return [s, p, o].join("\t") + " ."
end

def quote(str)
    return str.gsub('\\', '\\\\').gsub("\t", '\\t').gsub("\n", '\\n').gsub("\r", '\\r').gsub('"', '\\"').inspect
end

@sparql_ep = SPARQL.new(ARGV.shift)
refseq_json = ARGV.shift
output_ttl = ARGV.shift
output_tsv =  output_ttl.sub('.ttl', '.tsv')
idmapping_file = ARGV.shift
$tax_check_file = "refseq/current/refseq.tax.query.json"

@refseq_list = open("#{refseq_json}") do |io|
  JSON.load(io)
end

$taxid_list = {}
$taxup_list = {}
$tax_mismatch = {}
$gene_list = {}

$count = 0
$count_nc = 0
$no_up = 0

#save uniprot id and tax hash for maching
$uptax = {}
$upid = {}
def load_upids(idmap_file)
  cnt = 0
  id_map_file = File.open(idmap_file, "r")
  while line = id_map_file.gets
    up, xref, id = line.strip.split(/\s+/)
    case xref
    when "RefSeq"
      unless $upid[id]
        $upid[id] = []    
      end
      $upid[id] << up
    when "NCBI_TaxID"
      $uptax[up] = id
    end
    cnt += 1
    if (cnt % 100000 == 0)
     puts cnt
    end
  end
end


def output_header
#  $output_tsv.puts ["# NCBI taxonomy", "BioProject ID", "RefSeq ID", "Feature Resource ID", "Feature Label", "Feature Type", "Gene Resource ID", "Gene Label", "Protein ID", "UniProt taxonomy", "UniProt ID", "TogoGenome URI", "UniProt URI"].join("\t")

  $output_ttl.puts triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>")
  $output_ttl.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
  $output_ttl.puts triple("@prefix", "dct:", "<http://purl.org/dc/terms/>")
  $output_ttl.puts triple("@prefix", "togo:", "<http://togogenome.org/gene/>")
  $output_ttl.puts triple("@prefix", "upid:", "<http://identifiers.org/uniprot/>")
  $output_ttl.puts triple("@prefix", "tax:", "<http://identifiers.org/taxonomy/>")
  $output_ttl.puts triple("@prefix", "up:", "<http://purl.uniprot.org/uniprot/>")
  $output_ttl.puts triple("@prefix", "mir:", "<http://identifirs.org/miriam.resource/>")
  $output_ttl.puts triple("@prefix", "insdc:", "<http://ddbj.nig.ac.jp/ontologies/nucleotide/>")
  $output_ttl.puts
end

def output(refseq_data)
  rs = refseq_data
  $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:feature_rsrc]}>", "rdfs:seeAlso", "tax:#{rs[:taxid]}")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:feature_rsrc]}>", "rdf:type", "insdc:#{rs[:feature_type]}")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:feature_rsrc]}>", "rdfs:label", quote("#{rs[:feature_label]}"))
  $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:gene_rsrc]}>", "rdfs:seeAlso", "tax:#{rs[:taxid]}") unless $gene_list[rs[:gene_rsrc]]
  $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:gene_rsrc]}>", "rdf:type", "insdc:Gene") unless $gene_list[rs[:gene_rsrc]]
  $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:gene_rsrc]}>", "rdfs:label", quote("#{rs[:gene_label]}")) unless $gene_list[rs[:gene_rsrc]]
  $output_ttl.puts triple("tax:#{rs[:taxid]}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxid_list[rs[:taxid]]
  $taxid_list[rs[:taxid]] = true
  $gene_list[rs[:gene_rsrc]] = true
  
  if refseq_data[:protein_id] #has protein id
    protein_id = refseq_data[:protein_id]
    unless $upid[protein_id] == nil || $upid[protein_id].size == 0 #is match to up
      
      $upid[protein_id].each {|up|
        $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:feature_rsrc]}>", "rdfs:seeAlso", "upid:#{up}")
        $output_ttl.puts triple("<http://togogenome.org/gene/#{rs[:taxid]}:#{rs[:gene_rsrc]}>", "rdfs:seeAlso", "upid:#{up}")
        $output_ttl.puts triple("upid:#{up}", "rdf:type", "<http://identifiers.org/uniprot>")
        $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "up:#{up}")
        $output_ttl.puts triple("up:#{up}", "dct:publisher", "mir:MIR:00100134")  # UniProt (www.uniprot.org)
        taxup = $uptax[up] 
        if taxup
          $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "tax:#{taxup}")
          $taxup_list[taxup] = true
        end
        if taxup && rs[:taxid] != taxup
          $output_ttl.puts triple("tax:#{taxup}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxup_list[taxup]
          $tax_mismatch["#{rs[:taxid]}-#{taxup}"] = true
        end
      }
    else
      $no_up += 1
    end
  else
    $count_nc += 1
  end
  $count += 1
end

def get_feature_values
  template = File.read("#{@base_dir}/sparql/create_refseq2up_tsv.rq.erb")
  stats = {}
  @refseq_list.each {|refseq|
    rsid = refseq ["refseq_id"]
    #next unless (rsid == "NC_005120.4" || rsid == "NC_003272.1") #TODO delete 
    puts rsid
    query_text = ERB.new(template).result(binding)
    result = ""
    @sparql_ep.query(query_text, :format => 'json') do |json|
      result += json
    end
    result = JSON.parse(result)["results"]["bindings"]
    result.each do |entry|
      refseq_data = {
        :taxid => entry['taxonomy_id']['value'], 
        :bpid => entry['bioproject_id']['value'],
        :feature_rsrc => entry['feature']['value'],
        :feature_label => entry['feature_label']['value'],
        :feature_type => entry['feature_type']['value'],
        :gene_rsrc => entry['gene']['value'],
        :gene_label => entry['gene_label']['value'] 
      }
      if entry['protein_id']
        refseq_data[:protein_id] = entry['protein_id']['value']
      else
        refseq_data[:protein_id] = nil 
      end
      output(refseq_data)
    end
  }
end

def create_tax_check_file
=begin
  file = File.open($tax_check_file, "w")
  file.puts "taxid_list"
  file.puts $taxid_list.keys.size
  $taxid_list.keys.each do |key|
    file.puts key
  end
  file.puts "taxup_list"
  file.puts $taxup_list.keys.size
  $taxup_list.keys.each do |key|
    file.puts key
  end
  file.puts "tax_mismatchs"
  file.puts $tax_mismatch.keys.size
  $tax_mismatch.keys.each do |key|
    file.puts key
   end
=end
  File.open($tax_check_file, "w") do |file|
    file.puts %Q|{
    "count_taxid": #{$taxid_list.keys.size},
    "count_taxup": #{$taxup_list.keys.size},
    "count_tax_mismatch": #{$tax_mismatch.keys.size},
    "list_taxid": [ #{$taxid_list.keys.sort.join(', ')} ],
    "list_taxup": [ #{$taxup_list.keys.sort.join(', ')} ],
    "list_tax_mismatch": #{$tax_mismatch.keys.sort.inspect},
    "count_all_genes": #{$count},
    "count_non_coding": #{$count_nc},
    "count_no_uniprot": #{$no_up.size}
  }|
  end 
end
=begin
  File.open($tax_check_file, "w") do |file|
    file.puts %Q|{
    "count_taxid": #{$taxid_list.keys.size},
    "count_taxup": #{$taxup_list.keys.size},
    "count_tax_mismatch": #{$tax_mismatch.keys.size},
    "list_taxid": [ #{$taxid_list.keys.sort.join(', ')} ],
    "list_taxup": [ #{$taxup_list.keys.sort.join(', ')} ],
    "count_all_genes": #{$count},
    "count_non_coding": #{$count_nc},
    "count_no_uniprot": #{$no_up.size}
  }|
  end 
=end
#    "list_tax_mismatch": #{$tax_mismatch.keys.sort.inspect},

load_upids(idmapping_file)
puts $upid.size

#$output_tsv = File.open(output_tsv, "w")
$output_ttl = File.open(output_ttl, "w")

output_header()
get_feature_values()
create_tax_check_file()
#$output_tsv.close
$output_ttl.close
exit(0)

# Coding genes failed to map to UniProt
no_up = $pi.keys - pi_done.keys
no_up.each do |pi|
  taxid, bpid, rsid, feature, gene_id, pi = $pi[pi].strip.split("\t")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{feature_rsrc}>", "rdfs:seeAlso", "tax:#{taxid}")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{feature_rsrc}>", "rdf:type", "insdc:#{feature_type}")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{feature_rsrc}>", "rdfs:label", "#{feature_label}")
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_rsrc}>", "rdfs:seeAlso", "tax:#{taxid}") unless $gene_list[gene_rsrc]
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_rsrc}>", "rdf:type", "insdc:Gene") unless $gene_list[gene_rsrc]
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_rsrc}>", "rdfs:label", "#{gene_lable}") unless $gene_list[gene_rsrc]
  $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxid_list[taxid]
  $taxid_list[taxid] = true
  $gene_list[gene_rsrc] = true
end


=begin
$pi = {}
# ~ 4 min
File.open(refseq2up_file).each do |line|
  taxid, bpid, rsid, feature_rsrc, feature_label, feature_type, gene_rsrc, gene_label, protein_id = line.strip.split("\t")
  refseq_data = {:taxid => taxid, :bpid => bpid, :rsid => rsid,
                 :feature_rsrc => feature_rsrc, :feature_label => feature_label, :feature_type => feature_type,
                 :gene_rsrc => gene_rsrc, :gene_label => gene_label}
  if protein_id
    unless $pi[protein_id]
      $pi[protein_id] = []
    end
    $pi[protein_id] << refseq_data    
  else
    $output_tsv.puts line
    
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{feature_rsrc}>", "rdfs:seeAlso", "tax:#{taxid}")
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{feature_rsrc}>", "rdf:type", "insdc:#{feature_type}")
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{feature_rsrc}>", "rdfs:label", "#{feature_label}")
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_rsrc}>", "rdfs:seeAlso", "tax:#{taxid}") unless $gene_list[gene_rsrc]
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_rsrc}>", "rdf:type", "insdc:Gene") unless $gene_list[gene_rsrc]
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_rsrc}>", "rdfs:label", "#{gene_label}") unless $gene_list[gene_rsrc]
    $output_ttl.puts triple("tax:#{taxid}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $taxid_list[taxid]
    $taxid_list[taxid] = true
    $gene_list[gene_rsrc] = true
    count_nc += 1
  end
  count += 1
  #puts "#{count} (#{100.0 * count / 8116958}%)" if count % 100000 == 0
end
=end
