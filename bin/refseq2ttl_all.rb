#!/usr/bin/env ruby

require '/data/store/rdf/togogenome/bin/sparql.rb'
require 'json'
require 'fileutils'

input_dir = "refseq/current/prokaryotes.gb"
output_dir = "refseq/current/refseq.ttl"
output_all = "refseq/current/all.turtle"
#refseq2ttl = "bin/refseq2ttl.rb"
refseq2ttl = "bin/insdc2ttl/insdc2ttl.rb"

system(%Q[ruby #{refseq2ttl} -p > #{output_all}])

#[TODO] create common function to get seq list 
base_dir = File.dirname(__FILE__)
endpoint = SPARQL.new(ARGV.shift)

seq_qry = "#{base_dir}/sparql/get_refseq_retry.rq"
seq_lst = ""
endpoint.query(File.read(seq_qry), :format => 'json') do |json|
  seq_lst += json
end
seq_json = JSON.parse(seq_lst)
seq_body = seq_json["results"]["bindings"]

seq_body.map do |seq|
  tax_id = seq['tax_id']['value']
  prj_id = seq['bioproject_accession']['value']
  replicon_type = seq['replicon_type']['value']

  #ignore any human genome projects that aren't GCR project.
  next if tax_id == "9606" && prj_id != "PRJNA168"
  
  if !(File.exist?("#{output_dir}/#{tax_id}/#{prj_id}")) then
    # puts "mkdir_p #{output_dir}/#{tax_id}/#{prj_id}"
    FileUtils.mkdir_p("#{output_dir}/#{tax_id}/#{prj_id}")
  end

=begin
  seq_id = seq['seq_id']['value']
  # get sequence id which conforms to a id pattern of http://identifiers.org/refseq/
  if (seq_id =~ /^((AC|AP|NC|NG|NM|NP|NR|NT|NW|XM|XP|XR|YP|ZP)_\d+|(NZ\_[A-Z]{4}\d+))(\.\d+)?$/)
    seq_id = seq_id.split('.').first
    if replicon_type == "Chromosome"
      puts ">>> #{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl"
      $stderr.puts ">>> #{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl"
      system(%Q[ruby #{refseq2ttl} -d RefSeq -t "SO:chromosome" #{input_dir}/#{tax_id}/#{prj_id}/#{seq_id} > #{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl])
      system(%Q[grep -v '^@prefix' #{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl >> #{output_all}]) 
    else # expect Chromosome
      subdir = replicon_type.gsub(" ", "_")
      if !(File.exist?("#{subdir}")) then
        FileUtils.mkdir_p("#{output_dir}/#{tax_id}/#{prj_id}/#{subdir}")
      end
      seq_type = ""
      case replicon_type
      when "Plasmid"
        seq_type = "SO:plasmid"
      when "Mitochondrion"
        seq_type = "SO:mitochondrial_chromosome"
      else #[TODO] handle other sequence type
        seq_type = "SO:sequence"
      end
      if seq_type != "SO:sequence" #[TODO] remove this condition
        puts ">>> #{output_dir}/#{tax_id}/#{prj_id}/#{subdir}/#{seq_id}.ttl"
        $stderr.puts ">>> #{output_dir}/#{tax_id}/#{prj_id}/#{subdir}/#{seq_id}.ttl"
        system(%Q[ruby #{refseq2ttl} -d RefSeq -t #{seq_type} #{input_dir}/#{tax_id}/#{prj_id}/#{subdir}/#{seq_id} > #{output_dir}/#{tax_id}/#{prj_id}/#{subdir}/#{seq_id}.ttl])
        system(%Q[grep -v '^@prefix' #{output_dir}/#{tax_id}/#{prj_id}/#{subdir}/#{seq_id}.ttl >> #{output_all}])
      end
    end
  end   
=end

  seq_id_ver = seq['seq_id']['value']
  # get sequence id which conforms to a id pattern of http://identifiers.org/refseq/
  if seq_id_ver[/^((AC|AP|NC|NG|NM|NP|NR|NT|NW|XM|XP|XR|YP|ZP)_\d+|(NZ\_[A-Z]{4}\d+))(\.\d+)?$/]
    seq_id = seq_id_ver.split('.').first
    input_file = "#{input_dir}/#{tax_id}/#{prj_id}/#{seq_id}"
    if replicon_type != "Chromosome" #[TODO]delete this condition after fix the wget_refseq.rb
      subdir = replicon_type.gsub(" ", "_")
      input_file = "#{input_dir}/#{tax_id}/#{prj_id}/#{subdir}/#{seq_id}"
    end
    output_file = "#{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}.ttl"
    puts ">>> #{output_file}"
    $stderr.puts ">>> #{output_file}"
    system(%Q[ruby #{refseq2ttl} -d RefSeq -t "#{replicon_type}" #{input_file} > #{output_file}])
    system(%Q[grep -v '^@prefix' #{output_file} >> #{output_all}])
  end   
end
