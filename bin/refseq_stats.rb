#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql.rb"
require 'json'
require 'erb'
require 'fileutils'


class RefseqStats

  def initialize(endpoint, refseq_json)
    @sparql_ep = SPARQL.new(endpoint)
    @refseq_list = open("#{refseq_json}") do |io|
      JSON.load(io)
    end
    @base_dir = File.dirname(__FILE__)
  end

  def get_stats_values
    template = File.read("#{@base_dir}/sparql/stats_refseq.rq.erb")
    stats = {}
    @refseq_list.each {|refseq|
      taxid = refseq["tax_id"]
      assid = refseq ["assembly_accession"]
      bpid = refseq ["bioproject_id"]
      rsid = refseq ["refseq_id"]
      
#      next unless taxid == "243274" #delete

      stats[taxid] ||= {:seq_length => 0, :gene => 0, :pseudogene => 0, :trna => 0, :rrna => 0, :mrna => 0, :cds => 0, :exon => 0, :ncrna => 0, :other => 0, :assids => {}}
      stats[taxid][assid] ||= {:seq_length => 0, :gene => 0, :pseudogene => 0, :trna => 0, :rrna => 0, :mrna => 0, :cds => 0, :exon => 0, :ncrna => 0, :other => 0, :bpids => {}}
      stats[taxid][assid][bpid] ||= {:seq_length => 0, :gene => 0, :pseudogene => 0, :trna => 0, :rrna => 0, :mrna => 0, :cds => 0, :exon => 0, :ncrna => 0, :other => 0, :rsids => {} }
      stats[taxid][assid][bpid][rsid] ||= {:seq_length => 0, :gene => 0, :pseudogene => 0, :trna => 0, :rrna => 0, :mrna => 0, :cds => 0, :exon => 0, :ncrna => 0, :other => 0 }

      # for having uniq key of assid, bpid, rsid
      # ex stats["1148"][:assids] => {"GCF_000270265.1"=>true, "GCF_000340785.1"=>true, "GCF_000009725.1"=>true}
      stats[taxid][:assids][assid] = true
      stats[taxid][assid][:bpids][bpid] = true
      stats[taxid][assid][bpid][:rsids][rsid] = true
      
      query_text = ERB.new(template).result(binding)
      result_refseq_stats = ""
      @sparql_ep.query(query_text, :format => 'json') do |json|
        result_refseq_stats += json
      end
      result_cnt = JSON.parse(result_refseq_stats)["results"]["bindings"]
      puts "#{taxid} #{assid} #{bpid} #{rsid}"
      result_cnt.each do |refseq_stats|
        stats[taxid][assid][bpid][rsid][:seq_length] = refseq_stats['seq_length']['value'].to_i
        stats[taxid][assid][bpid][rsid][:gene] = refseq_stats['num_gene']['value'].to_i
        stats[taxid][assid][bpid][rsid][:pseudogene] = refseq_stats['num_pseudogene']['value'].to_i
        stats[taxid][assid][bpid][rsid][:trna] = refseq_stats['num_trna']['value'].to_i
        stats[taxid][assid][bpid][rsid][:rrna] = refseq_stats['num_rrna']['value'].to_i
        stats[taxid][assid][bpid][rsid][:mrna] = refseq_stats['num_mrna']['value'].to_i
        stats[taxid][assid][bpid][rsid][:cds] = refseq_stats['num_cds']['value'].to_i
        stats[taxid][assid][bpid][rsid][:exon] = refseq_stats['num_exon']['value'].to_i
        stats[taxid][assid][bpid][rsid][:ncrna] = refseq_stats['num_ncrna']['value'].to_i
        stats[taxid][assid][bpid][rsid][:other] = refseq_stats['num_other']['value'].to_i
      end
      #puts "#{taxid} #{assid} #{bpid} #{rsid}"
      #puts stats[taxid][assid][bpid][rsid]
    }
    stats
  end

  def output_ttl(stats, output_ttl)
    file = File.open(output_ttl, "w") 
    file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
    file.puts triple("@prefix", "stats:", "<http://togogenome.org/stats/>")
    file.puts

    stats.keys.each {|tax|
      stats[tax][:assids].keys.each {|ass|
        stats[tax][ass][:bpids].keys.each{|bp|
          stats[tax][ass][bp][:rsids].keys.each{|rs|
            output_feature_triples(file, "refseq", rs, stats[tax][ass][bp][rs])
            file.puts triple("<http://identifiers.org/bioproject/#{bp}>", "rdfs:seeAlso", "<http://identifiers.org/refseq/#{rs}>")
            #adding for sum by bioproject
            add_num_feature(stats[tax][ass][bp], stats[tax][ass][bp][rs])  
            #adding for sum by taxonomy 
            if stats[tax][:assids].keys.size > 1  # prevents duplicate count when taxonomy has multiple assembly report
              prior_ass = prior_ass(stats[tax])
              #if ass == stats[tax][:assids].keys.first #select one assembly accession
              if ass == prior_ass #select one assembly accession
                add_num_feature(stats[tax], stats[tax][ass][bp][rs])
              end
            else
              add_num_feature(stats[tax], stats[tax][ass][bp][rs])
            end
          }
          output_feature_triples(file, "bioproject", bp, stats[tax][ass][bp])
          file.puts triple("<http://identifiers.org/taxonomy/#{tax}>", "rdfs:seeAlso", "<http://identifiers.org/bioproject/#{bp}>")
        }
      }
      output_feature_triples(file, "taxonomy", tax, stats[tax])
    }
    file.close
  end

  #return maximum priority ssembly_accession of genomes have same tax_id.
  # order of priority [ reference genome > representative genome > released earlier ]
  def prior_ass(tax_stats)
    # get category and release data of genomes
    assemblies = {}
    tax_stats[:assids].keys.each {|ass|
      @refseq_list.each {|refseq|
        if ass == refseq["assembly_accession"] && !assemblies.has_key?(ass)
          refseq_category = refseq["refseq_category"]
          release_date = refseq["release_date"]
          assemblies["#{ass}"] = {:refseq_category => refseq_category, :release_date => release_date }
        end
      } 
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

  def add_num_feature (org, add)
    org[:seq_length] += add[:seq_length]
    org[:gene] += add[:gene]
    org[:pseudogene] += add[:pseudogene]
    org[:trna] += add[:trna]
    org[:rrna] += add[:rrna]
    org[:mrna] += add[:mrna]
    org[:cds] += add[:cds]
    org[:exon] += add[:exon]
    org[:ncrna] += add[:ncrna]
    org[:other] += add[:other]
  end 
  
  def output_feature_triples(file_writer, resource_type, resource_id, feature_stats)
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:sequence_length", feature_stats[:seq_length])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:gene", feature_stats[:gene])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:pseudogene", feature_stats[:pseudogene])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:trna", feature_stats[:trna])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:rrna", feature_stats[:rrna])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:mrna", feature_stats[:mrna])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:cds", feature_stats[:cds])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:exon", feature_stats[:exon])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:ncrna", feature_stats[:ncrna])
    file_writer.puts triple("<http://identifiers.org/#{resource_type}/#{resource_id}>", "stats:other", feature_stats[:other])
  end

  def triple(s, p, o)
    return [s, p, o].join("\t") + " ."
  end

end

endpoint = ARGV.shift
refseq_json = ARGV.shift
output_file = ARGV.shift
ref_stats = RefseqStats.new(endpoint, refseq_json)
stats_data = ref_stats.get_stats_values
ref_stats.output_ttl(stats_data, output_file)

