#!/usr/bin/env ruby
#
# % time ruby bin/refseq2gi-phase1.rb refseq/current/prokaryotes.gb > refseq/current/prokaryotes.gi
# ruby bin/refseq2gi-phase1.rb refseq/current/prokaryotes.gb >   2404.72s user 21.29s system 93% cpu 43:24.35 total
#

require 'rubygems'
require 'bio'
require 'json'

dir = ARGV.shift

stats = {}

Dir.glob("#{dir}/**/*").each do |file|
  next if File.directory?(file)
  next if file[/.txt$/]
  path = file.split('/')
  if file[/plasmids/]
    taxid = path[-4]
    bpid = path[-3]
  else
    taxid = path[-3]
    bpid = path[-2]
  end
  Bio::FlatFile.open(file).each do |entry|
    rsid = entry.acc_version
    features = entry.features
    source = features.shift

    stats[taxid] ||= {:gene => 0, :trna => 0, :rrna => 0, :other => 0}
    stats[taxid][bpid] ||= {:gene => 0, :trna => 0, :rrna => 0, :other => 0, :chromosome => 0, :plasmid => 0, :refseq => 0}
    stats[taxid][bpid][rsid] ||= {:gene => 0, :trna => 0, :rrna => 0, :other => 0}

    if file[/plasmids/]
      stats[taxid][bpid][:plasmid] += 1
    else
      stats[taxid][bpid][:chromosome] += 1
    end
    stats[taxid][bpid][:refseq] += 1

    features.each do |feature|
      feat = feature.feature
      hash = feature.to_hash
      case feat
      when "CDS"
        stats[taxid][:gene] += 1
        stats[taxid][bpid][:gene] += 1
        stats[taxid][bpid][rsid][:gene] += 1
      when "tRNA"
        stats[taxid][:trna] += 1
        stats[taxid][bpid][:trna] += 1
        stats[taxid][bpid][rsid][:trna] += 1
      when "rRNA"
        stats[taxid][:rrna] += 1
        stats[taxid][bpid][:rrna] += 1
        stats[taxid][bpid][rsid][:rrna] += 1
      else
        stats[taxid][:other] += 1
        stats[taxid][bpid][:other] += 1
        stats[taxid][bpid][rsid][:other] += 1
      end
      if hash["locus_tag"] and locus_tag = hash["locus_tag"].first
        if hash["db_xref"] and gixref = hash["db_xref"].find{|x| x[/GI:/]}
          gi = gixref.split(':', 2).last
          puts "#{taxid}\t#{bpid}\t#{rsid}\t#{locus_tag}\t#{gi}"
        end
      end
    end

  end
end

def triple(s, p, o)
  return [s, p, o].join("\t") + " ."
end

$stderr.puts stats.to_json

File.open("refseq/current/prokaryotes.stats", "w") do |file|
  file.puts triple("@prefix", "rdfs:", "<http://www.w3.org/2000/01/rdf-schema#>")
  file.puts triple("@prefix", "stats:", "<http://togogenome.org/stats/>")
  file.puts
  stats.each do |taxid, stats_tax|
    next if [:gene, :trna, :rrna, :other].include?(taxid)
    file.puts triple("<http://identifiers.org/taxonomy/#{taxid}>", "stats:gene", stats_tax[:gene])
    file.puts triple("<http://identifiers.org/taxonomy/#{taxid}>", "stats:trna", stats_tax[:trna])
    file.puts triple("<http://identifiers.org/taxonomy/#{taxid}>", "stats:rrna", stats_tax[:rrna])
    file.puts triple("<http://identifiers.org/taxonomy/#{taxid}>", "stats:other", stats_tax[:other])
    file.puts triple("<http://identifiers.org/taxonomy/#{taxid}>", "stats:bioproject", stats_tax.keys.size - 4)
    stats_tax.each do |bpid, stats_bp|
      next if [:gene, :trna, :rrna, :other].include?(bpid)
      file.puts triple("<http://identifiers.org/taxonomy/#{taxid}>", "rdfs:seeAlso", "<http://identifiers.org/bioproject/#{bpid}>")
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:gene", stats_bp[:gene])
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:trna", stats_bp[:trna])
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:rrna", stats_bp[:rrna])
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:other", stats_bp[:other])
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:chromosome", stats_bp[:chromosome])
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:plasmid", stats_bp[:plasmid])
      file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "stats:refseq", stats_bp[:refseq])
      stats_bp.each do |rsid, stats_rs|
        next if [:gene, :trna, :rrna, :other, :chromosome, :plasmid, :refseq].include?(rsid)
        file.puts triple("<http://identifiers.org/bioproject/#{bpid}>", "rdfs:seeAlso", "<http://identifiers.org/refseq/#{rsid}>")
        file.puts triple("<http://identifiers.org/refseq/#{rsid}>", "stats:gene", stats_rs[:gene])
        file.puts triple("<http://identifiers.org/refseq/#{rsid}>", "stats:trna", stats_rs[:trna])
        file.puts triple("<http://identifiers.org/refseq/#{rsid}>", "stats:rrna", stats_rs[:rrna])
        file.puts triple("<http://identifiers.org/refseq/#{rsid}>", "stats:other", stats_rs[:other])
      end
    end
  end
end

