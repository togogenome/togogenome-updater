#!/usr/bin/env ruby

require 'net/http'
require 'net/https'
require 'json'
require 'fileutils'
require 'date'

class GET_UNIPROT_RDF
  def initialize(tax_json_file, output_dir)
    unless File.directory?(output_dir)
      FileUtils.mkdir_p(output_dir)
    end
    @output_dir = output_dir
    @error_file = File.open("#{output_dir}/error.txt", "a+")
    @missing_file = File.open("#{output_dir}/refseq_missing.txt", "a+")
    @log_file = File.open("#{output_dir}/get_uniport_rdf.log", "a+")

    json = JSON.parse(File.read(tax_json_file))
    @taxids = json["list_taxid"].sort.uniq.map {|x| x.to_i}
  end

  def download_rdf()
    @taxids.each do |tax_id|
      Dir.chdir("#{@output_dir}") {
        #next unless tax_id.to_s == "103690"
        begin
          if !(File.exist?("#{tax_id}.rdf.gz")) then #ignore already exist
            log_txt = "[download rdf] tax_id:#{tax_id}"
            puts "curl -o #{tax_id}.rdf.gz 'https://rest.uniprot.org/uniprotkb/stream?query=organism_id:#{tax_id}&format=rdf&compressed=true' -w '%{http_code}' -s > status.txt"
            system("curl -o #{tax_id}.rdf.gz 'https://rest.uniprot.org/uniprotkb/stream?query=organism_id:#{tax_id}&format=rdf&compressed=true' -w '%{http_code}' -s > status.txt")
            download_flag = false
            if (File.exist?("#{tax_id}.rdf.gz")) && (File.exist?("status.txt"))
              download_flag = true if File.read("status.txt").to_s.start_with?("200")
            end
            log_txt += " first:#{download_flag}"
            unless download_flag == true # 再実行
              system("curl -o #{tax_id}.rdf 'https://rest.uniprot.org/uniprotkb/stream?query=organism_id:#{tax_id}&format=rdf&compressed=true' -w '%{http_code}' -s > status.txt")
              log_txt += " second:#{File.read("status.txt").to_s}"
              @missing_file.puts "#{tax_id}" unless File.read("status.txt").to_s.start_with?("200")
            end
            @log_file.puts log_txt
          end
        rescue => err
          @error_file.puts "Failed: #{tax_id} #{Time.now} (#{err})"
        end
      }
    end
  end
end

unless ARGV.size >= 2
  puts "./get_uniprot_rdf.rb <refseq_list_json> <output_dir>"
  exit(1)
end
get_uniprot = GET_UNIPROT_RDF.new(ARGV[0], ARGV[1])
get_uniprot.download_rdf()
