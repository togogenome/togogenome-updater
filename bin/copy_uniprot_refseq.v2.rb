#!/usr/bin/env ruby

require 'fileutils'
require 'json'

class RDF2Turtle

  def initialize(input_dir, output_dir)
    unless File.directory?(output_dir)
      FileUtils.mkdir_p(output_dir)
    end
    @error_file = File.open("#{output_dir}/error.txt", "a+")
    @missing_file = File.open("#{output_dir}/refseq_missing.txt", "a+")

    json_file = 'uniprot/current/refseq.tax.json'
    json = JSON.parse(File.read(json_file))
    taxids = (json["list_taxid"] + json["list_taxup"]).sort.uniq.map {|x| x.to_i}
    
    taxids.sort.each do |taxid|
      taxdir = (taxid / 1000) * 1000
      input_path = "#{input_dir}/#{taxdir}/#{taxid}.rdf"
      input_ttl_path = "#{input_path}".gsub(".rdf", ".ttl")
      output_path = "#{output_dir}/#{taxid}.ttl"
      command = "rapper -I http://purl.uniprot.org/ -i rdfxml -o turtle #{input_path} > #{output_path}"

      begin
        if !File.exists?(input_path)
          @missing_file.puts "#{taxid}"
        elsif File.exists?(output_path) # has already copied
          $stderr.puts "Skip #{output_path} ..."
        elsif File.exists?(input_ttl_path) # has already converted, create hard link
          link_command = "ln #{input_ttl_path} #{output_path}"
          system(link_command)
        else
          $stderr.puts "Converting #{input_path} => #{output_path} ..."
          fixrdf(input_path)
          system(command)
        end
      rescue => err
        @error_file.puts "Failed: #{Time.now} (#{err})"
        @error_file.puts command
      end

    end
  end

  def fixrdf(path)
    File.open(path, "a+") do |file|
      file.seek(-1024, IO::SEEK_END)
      tail = file.read
      unless tail[/<\/rdf:RDF>$/]
        file.puts "</rdf:RDF>"
        $stderr.puts "Fixed #{path} ..."
      end
    end
  end
end


input_dir = ARGV.shift || '../uniprot/current/uniprot_taxon.rdf'
output_dir = ARGV.shift || 'uniprot/current/refseq'

RDF2Turtle.new(input_dir, output_dir)
