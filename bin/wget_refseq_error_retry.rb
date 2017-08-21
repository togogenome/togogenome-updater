#!/usr/bin/env ruby

require 'json'
require 'fileutils'

prefix = "/data/store/rdf/togogenome/refseq/current"
output_dir = "#{prefix}/refseq.gb"
error_file = "#{prefix}/retry_wget_list.txt"

File.foreach(error_file) do |error_item|
  dirs = error_item.split("/")
  tax_id = dirs[-3]
  prj_id = dirs[-2]
  seq_id = dirs[-1]
  puts "#{output_dir}/#{tax_id}/#{prj_id}/#{seq_id}"
 
  Dir.chdir("#{output_dir}/#{tax_id}/#{prj_id}") {
    system("curl http://togows.dbcls.jp/entry/nucleotide/#{seq_id}?clear")
    FileUtils.rm("#{seq_id}")
    puts "try wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id} ..."
    system("wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}") unless $DEBUG
    if (File.exist?("#{seq_id}")) then # wget success
      puts "succeed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
    else
      puts "failed wget http://togows.dbcls.jp/entry/nucleotide/#{seq_id}"
    end
  }

end
