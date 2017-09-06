#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql.rb"
require 'json'
require 'erb'
require 'fileutils'


class RefseqStats

  def initialize(refseq_json)
    @refseq_list = open("#{refseq_json}") do |io|
      JSON.load(io)
    end
    @refseq_dir = "#{File.expand_path(File.dirname(refseq_json))}"
    @base_dir = File.dirname(__FILE__)
  end

  def get_stats_values
    # group by tax, assembly_data
    # {:tax_id=>"1148", 
    #  :assids=>{
    #   "GCF_000270265.1"=>
    #    [{"assembly_accession"=>"GCF_000270265.1", "tax_id"=>"1148", "bioproject_id"=>"PRJNA159873", "refseq_category"=>"na", "release_date"=>"2011/07/01", "molecule_name"=>"Chromosome", "refseq_id"=>"NC_017277.1"}],
    #   "GCF_000340785.1"=>
    #    [{"assembly_accession"=>"GCF_000340785.1", "tax_id"=>"1148"... 
    tax_ass = @refseq_list.group_by {|refseq|
      refseq["tax_id"]
    }.map {|key, value|
      assids = value.group_by {|ass|
        ass["assembly_accession"]
      }
      hash = {tax_id: key, assids: assids }
    }

    #count gc number from genbank file 
    result = tax_ass.map do |entry|
      #next unless entry[:tax_id] == "1148"
      # selects prior project, when taxonomy has multiple assembly.
      prior_ass = entry[:assids].keys.first 
      if entry[:assids].keys.size > 1
        prior_ass = prior_ass(entry)
      end
      # sequence list
      seq_list = entry[:assids][prior_ass].map {|ass|
        hash = {tax_id: ass["tax_id"], prj_id:ass["bioproject_id"], refseq_id: ass["refseq_id"]}
      }
      # gc and at count from genbank file
      count = seq_list.inject({at: 0, gc: 0}) do |result, seq_data|
        seq = open("#{@refseq_dir}/refseq.gb/#{seq_data[:tax_id]}/#{seq_data[:prj_id]}/#{seq_data[:refseq_id]}").read
        result[:at] += seq.count('a') + seq.count('t')
        result[:gc] += seq.count('g') + seq.count('c')
        result
      end
      count[:tax_id] = entry[:tax_id]
      p count
      count
    end
  end

  def output_ttl(stats, output_ttl)
    file = File.open(output_ttl, "w") 
    file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
    file.puts triple("@prefix", "stats:", "<http://togogenome.org/stats/>")
    file.puts

    stats.each {|tax_data|
      next if tax_data.nil? || tax_data.size == 0
      file.puts triple("<http://identifiers.org/taxonomy/#{tax_data[:tax_id]}>", "stats:gc_count", tax_data[:gc])
      file.puts triple("<http://identifiers.org/taxonomy/#{tax_data[:tax_id]}>", "stats:at_count", tax_data[:at])
    }
    file.close
  end

  #return maximum priority ssembly_accession of genomes have same tax_id.
  # order of priority [ reference genome > representative genome > released earlier ]
  def prior_ass(tax_stats)
    # get category and release data of genomes
    assemblies = {}
    tax_stats[:assids].each {|key,value|
      refseq_category = value.first["refseq_category"]
      release_date = value.first["release_date"]
      assemblies["#{key}"] = {:refseq_category => refseq_category, :release_date => release_date }
    }
    #compare
    reference = assemblies.select { |k, v| v[:refseq_category] == "reference genome" }
    if reference.size == 1
      return reference.keys.first
    elsif reference.size > 1 #if has multi reference genome, return released earlier
      return reference.min_by {|k, v| v[:release_date]}.first
    else #no reference genomes, check representative genome
      representative = assemblies.select { |k, v| v[:refseq_category] == "representative genome" }
      if representative.size == 1
        return representative.keys.first
      elsif representative.size > 1  #if has multi representative genome, return released earlier
        return representative.min_by {|k, v| v[:release_date]}.first
      else #no reference/representative genome, retrn released earlier
        return assemblies.min_by {|k, v| v[:release_date]}.first
      end
    end
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end

end

unless ARGV.size == 2
  puts "./refseq_stats_gc.rb <refseq_list_json> <output_file_path>"
  exit(1)
end

refseq_json = ARGV.shift
output_file = ARGV.shift
ref_stats = RefseqStats.new(refseq_json)
stats_data = ref_stats.get_stats_values
ref_stats.output_ttl(stats_data, output_file)
