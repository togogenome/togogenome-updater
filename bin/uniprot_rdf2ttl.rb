#!/usr/bin/env ruby

require 'fileutils'

class RDF2Turtle

  def initialize(input_dir, output_dir)
    # unzip
    Dir.glob("#{input_dir}/*.rdf.gz") do |input_path|
      system("gunzip #{input_path}")
    end
    rdf2ttl(input_dir, output_dir)
  end

  def rdf2ttl(input_dir, output_dir)
    FileUtils.makedirs(output_dir)
    @error_file = File.open("#{output_dir}/error.txt", "a+")

    Dir.glob("#{input_dir}/*.rdf") do |input_path|
      next if input_path.end_with?("11676.rdf")  # HIV-1 (too huge)
      output_path = input_path.sub(input_dir, output_dir).sub(".rdf", ".ttl")
      next if File.exist?(output_path)
      command = "rapper -I http://purl.uniprot.org/ -i rdfxml -o turtle #{input_path} > #{output_path}"
      begin
        if File.exists?(output_path)
          $stderr.puts "Skip #{output_path} ..."
          next
        else
          $stderr.puts "Writing #{output_path} ..."
          system(command)
        end
      rescue => err
        @error_file.puts "Failed: #{Time.now} (#{err})"
        @error_file.puts command
      end
    end
  end

end

input_dir = ARGV.shift
output_dir = ARGV.shift


RDF2Turtle.new(input_dir, output_dir)