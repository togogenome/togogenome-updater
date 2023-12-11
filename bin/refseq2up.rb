#!/usr/bin/env ruby
#
# 2013-11-01 21:13:42 load:0.81 -----
# % ruby bin/refseq2up-phase2.rb refseq/current/prokaryotes.up ../uniprot/current/uniprot_unzip/idmapping.dat > refseq/current/prokaryotes.tax.json
# 2013-11-02 02:14:46 load:3.26 (^-^)
#

@base_dir = File.dirname(__FILE__)

require 'rubygems'
require 'uri'
require 'date'
require 'json'
require 'erb'
require 'fileutils'
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
idmapping_file = ARGV.shift
$prepare_dir = File.expand_path('../refseq2up_prepare', output_ttl)
$tax_check_file = File.expand_path('../refseq.tax.json', output_ttl)

@refseq_list = open("#{refseq_json}") do |io|
  JSON.load(io)
end

$taxid_list = {}
$taxup_list = {}
$tax_mismatch = {}
$gene_list = {}
$gene_up_list = {}
$tax_type_list = {}

$count = 0
$count_nc = 0
$no_up = 0

#
# Parsing file idmapping.dat and output to a split file for each prefix.
# prefix of protein_id is the first to fifth string of protein_id. ("WP_00", "YP_01", ..)
# prefix of gene_id is first char of gene_id. ("1", "2", ..)
# ==== Args
# idmap_file : idmapping.dat file of UniProt
#
def split_upids(idmap_file)
  puts "split idmapping.dat to each prefix files"
  up_refp_output = prepare_prefix_files(idmap_file, "protein_id")
  up_refg_output = prepare_prefix_files(idmap_file, "gene_id")

  cnt = 0
  # it is assumed that the tax_id is followed by a protein_id or gene_id
  current_tax = {upid: nil, tax_id: nil}
  taxid_missing_list = [] 
  File.open(idmap_file, "r") do |f|
    f.each_line do |line|
      up, xref, id = line.strip.split("\t")
      case xref
      when "NCBI_TaxID"
        current_tax = {upid: up.split("-").first, tax_id: id}
      when "RefSeq", "GeneID"
        # Push only the tax_id with refseq protein_id or gene_id
        if current_tax[:upid] == up.split("-").first
          if xref == "RefSeq"
            prefix = id.chomp.strip[0..4]
            up_refp_output[prefix].puts line.chomp.strip + "\t" + current_tax[:tax_id]
          elsif xref == "GeneID"
            prefix = id.chomp.strip[0]
            up_refg_output[prefix].puts line.chomp.strip + "\t" + current_tax[:tax_id]
          end
        else
          taxid_missing_list.push(up)
        end
      end
      cnt += 1
      if (cnt % 100000 == 0)
        puts cnt
      end
    end
    # list of upid that can't get taxid. Depends on the order of idmapping.dat
    out = File.open("taxid_missing_list.json", "w") unless taxid_missing_list.size == 0
    taxid_missing_list.each do |upid|
      out.puts JSON.pretty_generate(taxid_missing_list)
    end
  end

  # close files
  up_refp_output.each do |k, v|
    v.flush
    v.close
  end
  up_refg_output.each do |k, v|
    v.flush
    v.close
  end
end

#
# Get a list of prefixes and prepare their output files.
# ==== Args
# mode : "protein_id" or "gene_id"
# ==== Return
# Hash with prefixs(protein_id or gene_id) as a key.  The value is a file object to  output
# { "WP_00" => #<File:./refseq2up_prepare/up_refp/WP_00.dat>,  "WP_01" => #<File:./refseq2up_prepare/up_refp/WP_01.dat>, ...}
def prepare_prefix_files(idmap_file, mode)
  FileUtils.mkdir_p($prepare_dir) unless File.exist?($prepare_dir)
  if mode == "protein_id"
    prefix_list_file = "up_refp_prefix_list.txt"
    system(%Q[grep 'RefSeq' #{idmap_file} | cut -f3 | cut -c1-5 | sort | uniq > #{$prepare_dir}/#{prefix_list_file} ]) # get exist prefix list of protein_id
    FileUtils.mkdir_p("#{$prepare_dir}/up_refp") unless File.exist?("#{$prepare_dir}/up_refp")
  elsif mode == "gene_id"
    prefix_list_file = "up_refg_prefix_list.txt"
    system(%Q[grep 'GeneID' #{idmap_file} | cut -f3 | cut -c1 | sort | uniq > #{$prepare_dir}/#{prefix_list_file} ]) # get exist prefix list of gene_id
    FileUtils.mkdir_p("#{$prepare_dir}/up_refg") unless File.exist?("#{$prepare_dir}/up_refg")
  end
  
  # create output object to each prefix files
  prefix_output = {}
  File.open("#{$prepare_dir}/#{prefix_list_file}") do |f|
    f.each_line do |line|
      prefix = line.chomp.strip
      if mode == "protein_id"
        prefix_output[prefix] = File.open("#{$prepare_dir}/up_refp/#{prefix}.dat", "w")
      elsif mode == "gene_id"
        prefix_output[prefix] = File.open("#{$prepare_dir}/up_refg/#{prefix}.dat", "w")
      end
    end
  end
  prefix_output
end

#
# Get RefSeq's gene(feature) list with SPARQL and output all result to a file.
# 
# ==== Args
# idmap_file : idmapping.dat file of UniProt
#
def get_feature_values
  out = File.open("#{$prepare_dir}/refseq_genes_result.tsv", "w")
  template = File.read("#{@base_dir}/sparql/create_refseq2up_tsv.rq.erb")
  stats = {}
  @refseq_list.each {|refseq|
    retry_cnt = 0 #prevent from infinite loop
    rsid = refseq ["refseq_id"]
    #next unless (rsid == "NZ_CP011382.1" || rsid == "NC_003272.1" || rsid == "NC_000010.11") #TODO delete
    query_text = ERB.new(template).result(binding)
    begin
      result = ""
      puts rsid
      @sparql_ep.query(query_text, :format => 'json') do |json|
        result += json
      end
      $stderr.puts "success get featurs of #{rsid} ."
      result = JSON.parse(result)["results"]["bindings"]
    rescue # when occures timeout or json parse error
      retry_cnt += 1
      $stderr.puts "error get featurs of #{rsid} ."
      if retry_cnt <= 10
        $stderr.puts "start retry after 30 sec..."
        sleep 30
        retry
      else #prevent from infinite loop
        $stderr.puts "finally, cloudn't get featurs of #{rsid} . Please check the data or environment"
        next
      end
    end
    result.each do |entry|
      refseq_data = [
        entry['taxonomy_id']['value'],
        entry['gene']['value'],
        entry['gene_label']['value']
      ]
      if entry['protein_id']
        refseq_data.push(entry['protein_id']['value'])
      else
        refseq_data.push("")
      end
      if entry['insdc_gene_id']
        refseq_data.push(entry['insdc_gene_id']['value'])
      else
        refseq_data.push("")
      end
      out.puts refseq_data.join("\t")
    end
  }
  out.flush
  out.close
end

#
# Parsing file RefSeq genes list and output to a split file for each prefix.
# prefix of protein_id is the first to fifth string of protein_id. ("WP_00", "YP_01", ..)
#
def split_refseq
  # prepare output files
  system(%Q[cut -f4 #{$prepare_dir}/refseq_genes_result.tsv | cut -c1-5 | sort | uniq > #{$prepare_dir}/refp_prefix_list.txt ]) # get exist prefix list of protein_id
  FileUtils.mkdir_p("#{$prepare_dir}/refp") unless File.exist?("#{$prepare_dir}/refp")
  refp_output = {}
  File.open("#{$prepare_dir}/refp_prefix_list.txt") do |f|
    f.each_line do |line|
      prefix = line.chomp.strip
      refp_output[prefix] = File.open("#{$prepare_dir}/refp/#{prefix}.dat", "w")
    end
  end
  refp_output["no_protein_id"] = File.open("#{$prepare_dir}/refp/no_protein_id.dat", "w") # protein_id is optional

  File.open("#{$prepare_dir}/refseq_genes_result.tsv") do |f|
    f.each_line do |line|
      columns = line.chomp.strip.split("\t")
      prefix = (columns[3].nil? || columns[3] == "") ? "no_protein_id" : columns[3][0..4] # protein_id is optional
      refp_output[prefix].puts line.chomp.strip
    end
  end
  refp_output.each do |k, v|
    v.flush
    v.close
  end
end

#
# Map the UniProt and RefSeq gene by protein_id. 
#
def map_tgup_by_proteinid()
  # output unmatch list for map by gene_id (prefix of gene_id is first char of gene_id. ("1", "2", ..))
  refg_output = {}
  FileUtils.mkdir_p("#{$prepare_dir}/refg") unless File.exist?("#{$prepare_dir}/refg")
  (1..9).each do |prefix|
    refg_output[prefix.to_s] = File.open("#{$prepare_dir}/refg/#{prefix.to_s}.dat", "w")
  end

  output_header

  # try mapping the same prefix of RefSeq data and UniProt data(for performance)
  Dir.glob("#{$prepare_dir}/refp/*.dat") do |input_file|
    # parse data
    refseq_gene_list = []
    protein_id_prefix = input_file.split("/").last.split("\.").first
    puts "protein_id prefix: #{protein_id_prefix}"
    File.open(input_file) do |f|
      f.each_line do |line|
        columns = line.chomp.strip.split("\t")
        gene_id_prefix  = columns[4].nil? ? "" : columns[4][0]
        refseq_gene_list.push({taxid: columns[0], gene_rsrc: columns[1], gene_label: columns[2], protein_id: columns[3], gene_id: columns[4], gene_id_prefix: gene_id_prefix})
      end
    end

    $count_nc += refseq_gene_list.size if protein_id_prefix == "no_protein_id" # no protein_id on RefSeq
    up_list = load_up_refp(protein_id_prefix) # get same prefix data from UniProt

    refseq_gene_list.each do |refseq_data|
      match = false
      output_tax(refseq_data) # output all gene-tax turtle
      unless up_list.nil? # exist prefix on UniProt
        match_list = up_list[refseq_data[:protein_id]]
        unless match_list.nil? # match some uniprot_ids
          match_list.each do |up_info|
            if refseq_data[:taxid] == up_info[:taxid] # ignore unmatch tax
              output_idmap(refseq_data, up_info[:upid])
              match = true
            else # match protein_id but not match tax_id
              output_uptax(up_info)
              $taxup_list[up_info[:taxid]] = true
              $tax_mismatch["#{refseq_data[:taxid]}-#{up_info[:taxid]} : #{refseq_data[:protein_id]}"] = true
            end
          end
        end
      end
      if match == false
        if refseq_data[:gene_id_prefix].nil? ||refseq_data[:gene_id_prefix] == "" # can't salvage it by gene_id.
          $no_up += 1
        else # output a file to each prefix of gene_id that can be salvaged by gene_id
          line = [refseq_data[:taxid], refseq_data[:gene_rsrc], refseq_data[:gene_label], refseq_data[:protein_id], refseq_data[:gene_id], refseq_data[:gene_id_prefix]]
          refg_output[refseq_data[:gene_id_prefix]].puts(line.join("\t"))
        end
      end
      $count += 1
    end
  end
  refg_output.each do |k, v|
    v.flush
    v.close
  end
end

#
# Map the UniProt and RefSeq gene by gene_id. (Normally, the data that cannot be mapped by protein_id are targeted.)
#
def map_tgup_by_geneid()
  Dir.glob("#{$prepare_dir}/refg/*.dat") do |input_file|
    refseq_gene_list = []
    gene_id_prefix = input_file.split("/").last.split("\.").first
    puts "gene_id prefix: #{gene_id_prefix}"
    File.open(input_file) do |f|
      f.each_line do |line|
        columns = line.chomp.strip.split("\t")
        refseq_gene_list.push({taxid: columns[0], gene_rsrc: columns[1], gene_label: columns[2], protein_id: columns[3], gene_id: columns[4], gene_id_prefix: gene_id_prefix})
      end
    end

    up_list = load_up_refg(gene_id_prefix) # get same prefix data from UniProt
    refseq_gene_list.each do |refseq_data|
      match = false
      unless up_list.nil? # exist prefix list on UniProt
        match_list = up_list[refseq_data[:gene_id]]
        unless match_list.nil?
          match_list.each do |up_info|
            if refseq_data[:taxid] == up_info[:taxid]
              output_idmap(refseq_data, up_info[:upid])
              match = true
            end
          end
        end
      end
      if match == false
        $no_up += 1
      end
    end
  end
end

# returns the Uniprot ID mapping hash in the specified prefix of protein_id
# ==== Args
# prefix : prefix of gene_id. ex "WP_01", "YP_00", ..
# ==== Return
# Hash with RefSeq protein_id as a key. The value is a list of the corresponding UniProt for that protein.
# { "YP_001552269.1" => [{upid: "A9CBA2", protein_id: "YP_001552269.1", taxid: "189830"}] , "YP_001569032.1" => [{upid: "P15256", protein_id: "YP_001569032.1", taxid: "555217"}] ,}
def load_up_refp(prefix)
  return nil unless File.exist?("#{$prepare_dir}/up_refp/#{prefix}.dat")
  up_refp_list = []
  File.open("#{$prepare_dir}/up_refp/#{prefix}.dat") do |f|
    f.each_line do |line|
      columns = line.chomp.strip.split("\t")
      up_refp_list.push({upid: columns[0], protein_id: columns[2], taxid: columns[3]})
    end
  end
  up_refp_list.group_by{|row| row[:protein_id]}
end

# returns the Uniprot ID mapping hash in the specified prefix of gene_id
# ==== Args
# prefix : prefix of gene_id. ex "1", "5"
# ==== Return
# Hash with RefSeq gene_id as a key. The value is a list of the corresponding UniProt for that protein.
# { "59272" => [{upid: "Q9BYF1", gene_id: "59272", taxid: "9606"}] , "55743" => [{upid: "Q96EP1", gene_id: "55743", taxid: "9606"}] ,}
def load_up_refg(prefix)
  return nil unless File.exist?("#{$prepare_dir}/up_refg/#{prefix}.dat")
  up_refg_list = []
  File.open("#{$prepare_dir}/up_refg/#{prefix}.dat") do |f|
    f.each_line do |line|
      columns = line.chomp.strip.split("\t")
      up_refg_list.push({upid: columns[0], gene_id: columns[2], taxid: columns[3]})
    end
  end
  up_refg_list.group_by{|row| row[:gene_id]}
end

def output_header
  $output_ttl.puts triple("@prefix", "rdf:", "<http://www.w3.org/1999/02/22-rdf-syntax-ns#>")
  $output_ttl.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
  $output_ttl.puts triple("@prefix", "owl:", "<http://www.w3.org/2002/07/owl#>")
  $output_ttl.puts triple("@prefix", "dct:", "<http://purl.org/dc/terms/>")
  $output_ttl.puts triple("@prefix", "togo:", "<http://togogenome.org/gene/>")
  $output_ttl.puts triple("@prefix", "upid:", "<http://identifiers.org/uniprot/>")
  $output_ttl.puts triple("@prefix", "tax:", "<http://identifiers.org/taxonomy/>")
  $output_ttl.puts triple("@prefix", "up:", "<http://purl.uniprot.org/uniprot/>")
  $output_ttl.puts triple("@prefix", "mir:", "<http://identifirs.org/miriam.resource/>")
  $output_ttl.puts triple("@prefix", "insdc:", "<http://ddbj.nig.ac.jp/ontologies/nucleotide/>")
  $output_ttl.puts triple("@prefix", "skos:", "<http://www.w3.org/2004/02/skos/core#>")
  $output_ttl.puts
end

# output ttl of RefSeq gene and TaxID mapping
def output_tax(refseq_data)
  rs = refseq_data
  taxid = rs[:taxid]
  gene_label_url = URI.escape(rs[:gene_label])

  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_label_url}>", "rdfs:seeAlso", "tax:#{rs[:taxid]}") unless $gene_list[rs[:gene_rsrc]]
  $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_label_url}>", "skos:exactMatch", "<http://identifiers.org/refseq/#{rs[:gene_rsrc]}>") unless $gene_list[rs[:gene_rsrc]]
  $output_ttl.puts triple("tax:#{rs[:taxid]}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $tax_type_list[rs[:taxid]]
  $tax_type_list[rs[:taxid]] = true # to prevent duplicate output
  $gene_list[rs[:gene_rsrc]] = true # to prevent duplicate output
end

# output ttl of UniProt and TaxID mapping
def output_uptax(up_data)
  taxup = up_data[:taxid]
  $output_ttl.puts triple("tax:#{taxup}", "rdf:type", "<http://identifiers.org/taxonomy>") unless $tax_type_list[taxup]
  $tax_type_list[taxup] = true # to prevent duplicate output
end

# output ttl of UniProt and RefSeq gene mapping
def output_idmap(refseq_data, up)
  taxid = refseq_data[:taxid]
  gene_label_url = URI.escape(refseq_data[:gene_label])
  up = up.split("-").first if up.index("-") # with "-" means isoform's ID. expect to protein's ID

  unless $gene_up_list["#{refseq_data[:gene_rsrc]}:#{up}"]
    $output_ttl.puts triple("<http://togogenome.org/gene/#{taxid}:#{gene_label_url}>", "rdfs:seeAlso", "upid:#{up}")
    $output_ttl.puts triple("upid:#{up}", "rdf:type", "<http://identifiers.org/uniprot>")
    $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "up:#{up}")
    $output_ttl.puts triple("up:#{up}", "dct:publisher", "<http://identifirs.org/miriam.resource/MIR:00100134>")  # UniProt (www.uniprot.org)
    $output_ttl.puts triple("upid:#{up}", "rdfs:seeAlso", "tax:#{taxid}")
    $gene_up_list["#{refseq_data[:gene_rsrc]}:#{up}"] = true # to prevent duplicate output
    $taxid_list[taxid] = true
  end
end

def create_tax_check_file
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

split_upids(idmapping_file)
get_feature_values()
split_refseq()
$output_ttl = File.open(output_ttl, "w")
map_tgup_by_proteinid()
map_tgup_by_geneid()
$output_ttl.close
create_tax_check_file()