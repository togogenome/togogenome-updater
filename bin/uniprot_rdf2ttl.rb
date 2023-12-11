#!/usr/bin/env ruby

require 'fileutils'

class RDF2Turtle

  def initialize(input_dir, output_dir)
    FileUtils.makedirs(output_dir)
    @error_file = File.open("#{output_dir}/error.txt", "a+")

    Dir.glob("#{input_dir}/[0-9]*").sort_by{|path| path[/\d+$/].to_i}.each do |dir|
      $stderr.puts "Converting files in #{dir} ..."
      FileUtils.makedirs("#{output_dir}/#{File.basename(dir)}")

      Dir.glob("#{dir}/*").sort_by{|path| path[/(\d+).rdf/,1].to_i}.each do |input_path|
        next if input_path[/\/0\/0.rdf/]        # obsolete entries (useless)
        next if input_path[/11000\/11676.rdf/]  # HIV-1 (too huge)

        output_path = input_path.sub(input_dir, output_dir).sub(".rdf", ".ttl")
        # TODO rapperコンテナが必要
        command = "rapper -I http://purl.uniprot.org/ -i rdfxml -o turtle #{input_path} > #{output_path}"

        begin
          if File.exists?(output_path)
            $stderr.puts "Skip #{output_path} ..."
            next
          else
            $stderr.puts "Writing #{output_path} ..."
            fixrdf(input_path)
            system(command)
          end
        rescue => err
          @error_file.puts "Failed: #{Time.now} (#{err})"
          @error_file.puts command
        end
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


input_dir = ARGV.shift
output_dir = ARGV.shift


RDF2Turtle.new(input_dir, output_dir)

