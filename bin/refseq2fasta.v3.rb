#!/usr/bin/env ruby

@base_dir = File.dirname(__FILE__)

require 'rubygems'
require 'bio'
require 'erb'
require "./#{@base_dir}/sparql.rb"

@sparql_ep = SPARQL.new("http://dev.togogenome.org/sparql-test")
@template = File.read("#{@base_dir}/sparql/get_tax_domain.rq.erb")
@tax_domain_hash = {}


def get_tax_category (tax_id)
  if @tax_domain_hash.has_key?(tax_id)
    return @tax_domain_hash["#{tax_id}"]
  else
    result = ""
    query_text = ERB.new(@template).result(binding)
    @sparql_ep.query(query_text, :format => 'json') do |json|
      result += json
    end
    result = JSON.parse(result)["results"]["bindings"]  
    if result.size > 0
      if result.size == 2 # if returns 33208(Metazoa) or 33090(Viridiplantae), also returns 2759
        detail_id = result.find {|row| row["tax_domain"]["value"].split("/").last != "2759"}
        domain_tax_id = detail_id["tax_domain"]["value"].split("/").last
      else 
        domain_tax_id = result.first["tax_domain"]["value"].split("/").last
      end
      @tax_domain_hash["#{tax_id}"] = domain_tax_id
      return domain_tax_id
    else
      @tax_domain_hash["#{tax_id}"] = "other"
      return "other"
    end
  end
end

output_metazoa = File.open("refseq/current/metazoa.fasta", "a")
output_viridiplantae = File.open("refseq/current/viridiplantae.fasta", "a")
output_eukaryota = File.open("refseq/current/eukaryota.fasta", "a")
output_prokaryota = File.open("refseq/current/prokaryota.fasta", "a")

Dir.glob("refseq/current/refseq.gb/**/*").each do |file|
  next if File.directory?(file)
  next if file[/.txt$/]

  path = file.split('/')

  tax = path[-3]
  prj = path[-2]
  ent = path[-1]
  domain_tax_id = get_tax_category(tax)
  Bio::FlatFile.auto(file).each do |entry|
    prefix = "refseq/current/refseq.ttl/#{tax}/#{prj}/#{ent}"
    next unless File.exists?("#{prefix}.ttl")
#    File.open("#{prefix}.fasta", "w") do |output|
      desc = %Q[refseq:#{entry.acc_version} {"definition":"#{entry.definition}", "taxonomy":"#{tax}", "bioproject":"#{prj}", "refseq":"#{entry.acc_version}"}]
      $stderr.puts desc
#TODO      output.puts entry.seq.to_fasta(desc, 50)
      # Separates eukaryota and prokaryota, since it's too large for GGGenome
      if domain_tax_id == "33208" # Metazoa animal
        output_metazoa.puts entry.seq.to_fasta(desc, 50)
      elsif domain_tax_id == "33090" # Viridiplantae (plant)
        output_viridiplantae.puts entry.seq.to_fasta(desc, 50)
      elsif domain_tax_id == "2759" # other eukaryota
        output_eukaryota.puts entry.seq.to_fasta(desc, 50)
      else #prokaryota
        output_prokaryota.puts entry.seq.to_fasta(desc, 50)
      end
#    end
  end
end
puts JSON.pretty_generate(@tax_domain_hash)
