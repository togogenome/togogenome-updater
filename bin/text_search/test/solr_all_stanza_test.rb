#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'systemu'

TOGO_DIR = '/data/store/rdf/togogenome'
BASE_DIR = "#{TOGO_DIR}/bin/text_search"

if ARGV.size == 1
  if ARGV[0] == "master"
    output_dir = "#{TOGO_DIR}/text_search/current/test/result"
    solr_url = "http://togogenome.org/solr"
  elsif ARGV[0] == "dev"
    output_dir = "#{TOGO_DIR}/text_search/current/test/result_dev"
    solr_url = "http://localhost:15963/solr"
  else
    puts "./solr_all_stanza_test.rb <mode>"
    puts "mode [ master | dev ]"
    exit(1)
  end
else
  puts "./solr_all_stanza_test.rb <mode>"
  puts "mode [ master | dev ]"
  exit(1)
end

test_data = JSON.parse(File.read("#{BASE_DIR}/test/solr_all_stanza_test.json"))
FileUtils.mkdir_p("#{output_dir}")

Dir.chdir("#{output_dir}") {
  test_data.each do |row|
    stanza_name = row["stanza_name"]
    qtext = row["q"]
    wget_command = %Q(wget -O #{stanza_name}.json "#{solr_url}/#{stanza_name}/select?q=text:#{qtext} OR id_text:#{qtext}&wt=json&indent=true")
    p wget_command
    systemu wget_command
    # output result to check
    puts "stanza:#{stanza_name}, query:#{qtext}"
    ret_json = JSON.parse(File.read("#{output_dir}/#{stanza_name}.json"))
    num_found = ret_json["response"]["numFound"]
    if num_found.to_i > 0
      puts "hit num:#{num_found}"
    #  first_data = ret_json["response"]["docs"].first
    #  p first_data
    else
      puts "WARNING! Please check the solr index data."
    end
  end
}
