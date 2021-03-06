#!/usr/bin/env ruby

#require 'xz'
#require 'zlib'
require 'open3'
require 'fileutils'
require 'systemu'
require 'json'

class UniProtTaxonomySplitter

  @@head = <<HEAD
<?xml version='1.0' encoding='UTF-8'?>
<rdf:RDF xml:base="http://purl.uniprot.org/uniprot/" xmlns="http://purl.uniprot.org/core/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:owl="http://www.w3.org/2002/07/owl#" xmlns:skos="http://www.w3.org/2004/02/skos/core#" xmlns:bibo="http://purl.org/ontology/bibo/" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:void="http://rdfs.org/ns/void#" xmlns:sd="http://www.w3.org/ns/sparql-service-description#" xmlns:faldo="http://biohackathon.org/resource/faldo#">
<owl:Ontology rdf:about="http://purl.uniprot.org/uniprot/">
<owl:imports rdf:resource="http://purl.uniprot.org/core/"/>
</owl:Ontology>
HEAD

  @@tail = <<TAIL
</rdf:RDF>
TAIL

  @@rs = /<rdf:Description rdf:about="http:\/\/purl\.uniprot\.org\/uniprot\/\w+">/
  @@tx = '<organism rdf:resource="http://purl.uniprot.org/taxonomy/'

  @@created_dirs = {}

  def initialize(uniprot_rdf_dir, dir)
    @input_dir = uniprot_rdf_dir
    @output_dir = dir

    FileUtils.makedirs(@output_dir)
    @error_file = File.open("#{@output_dir}/error.txt", "w+")

    split_entries
    add_tails
  end

  def taxid2file(taxid)
    taxdir = (taxid / 1000) * 1000
    dirpath = "#{@output_dir}/#{taxdir}"
    filepath = "#{dirpath}/#{taxid}.rdf"
    unless @@created_dirs[dirpath]
      FileUtils.makedirs(dirpath)
      @@created_dirs[dirpath] = true
    end
    unless File.exists?(filepath)
      File.open(filepath, "w+") do |file|
        file.puts @@head
      end
    end
    return filepath
  end

  def output_entry(rdf_entry, count)
    begin
      rdf_entry.slice!("\n</rdf:RDF>") # exclude footer
      taxid = rdf_entry[/#{@@tx}(\d+)/, 1].to_i
      taxid_file = taxid2file(taxid)
      $stderr.puts "#{count}: #{taxid_file}"

      File.open(taxid_file, "a+") do |output_file|
        output_file.puts rdf_entry
      end
    rescue => err
      @error_file.puts "Failed: #{Time.now} (#{err})"
      @error_file.puts block.inspect
    end
  end

  def split_entries
    count = 0
    Dir::glob("#{@input_dir}/*.rdf").each do |file|
      header_flag = true
      current_entry = ""
      current_block = []
      File.foreach(file).slice_before(@@rs).each do |block|
        if !header_flag # exclude header
          if !current_entry.start_with?("<?xml") && current_entry != block.first
            count += 1
            output_entry(current_block.join, count)
            current_block = block
            current_entry = block.first
          else
            current_block.concat(block)
            current_entry = block.first
          end
        end
        header_flag = false
      end  # File.foreach(file).slice_before(rs) 
      count += 1
      output_entry(current_block.join, count)
    end  # Dir::glob.each(file)
  end  # def split_entries

  def add_tails
    @@created_dirs.sort_by{|k,v| k[/\d+/].to_i}.each do |dir, value|
      $stderr.puts "Fixing files in #{dir} ..."
      Dir.glob("#{dir}/*").sort.each do |path|
        File.open(path, "a+") do |file|
          file.puts @@tail
        end
      end
    end
  end

end  # class UniProtTaxonomySplitter

uniprot_rdf_dir = ARGV.shift
output_dir = ARGV.shift

UniProtTaxonomySplitter.new(uniprot_rdf_dir, output_dir)
