#!/usr/bin/env ruby

require 'fileutils'
require 'json'

class RDF2Turtle

  def initialize(tax_json_file, input_dir, output_dir)
    unless File.directory?(output_dir)
      FileUtils.mkdir_p(output_dir)
    end
    @error_file = File.open("#{output_dir}/error.txt", "a+")
    @missing_file = File.open("#{output_dir}/refseq_missing.txt", "a+")

    json = JSON.parse(File.read(tax_json_file))
    taxids = (json["list_taxid"] + json["list_taxup"]).sort.uniq.map {|x| x.to_i}

    taxids.sort.each do |taxid|
      taxdir = (taxid / 1000) * 1000
      input_path = "#{input_dir}/#{taxdir}/#{taxid}.rdf"
      output_path = "#{output_dir}/#{taxid}.rdf"

      begin
        if !File.exists?(input_path)
          @missing_file.puts "#{taxid}"
        else
          if File.exists?(output_path) # has already copied
            $stderr.puts "Skip #{output_path} ..."
          else #create hard link
            link_command = "ln #{input_path} #{output_path}"
            system(link_command)
          end
        end
      rescue => err
        @error_file.puts "Failed: #{Time.now} (#{err})"
      end

    end
  end
end

tax_json_file = ARGV.shift || 'uniprot/current/refseq.tax.json'
input_dir = ARGV.shift || '../uniprot/current/uniprot_taxon.rdf'
output_dir = ARGV.shift || 'uniprot/current/refseq'

RDF2Turtle.new(tax_json_file, input_dir, output_dir)
