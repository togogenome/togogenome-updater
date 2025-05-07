#!/usr/bin/env ruby

base_dir = File.dirname(__FILE__)

require "./#{base_dir}/sparql.rb"
require 'json'
require 'fileutils'
require 'erb'

endpoint = SPARQL.new(ARGV.shift)
result_list = []

template = File.read("#{base_dir}/sparql/get_refseq_list.erb")
sparql = ERB.new(template).result(binding)
result = ""
endpoint.query(sparql, :format => 'json') do |json|
  result += json
end

results = JSON.parse(result)["results"]["bindings"]
result_list.concat(results)

# 例外的に取得する accessionの情報を取得
additional_refseq_list = JSON.parse(File.read("./#{base_dir}/additional_refseq_list.json"))
additional_refseq_list.each do |additional_refseq|
  template = File.read("#{base_dir}/sparql/get_refseq_add_list.erb")
  sparql = ERB.new(template).result(binding)
  result = ""
  endpoint.query(sparql, :format => 'json') do |json|
    result += json
  end
  results = JSON.parse(result)["results"]["bindings"]
  result_list.concat(results)
end

list = result_list.map do |entry|
  hash = {
          :assembly_accession => entry['assembly_accession']['value'],
          :tax_id => entry['tax_id']['value'],
          :bioproject_id => entry['bioproject_accession']['value'],
          :refseq_category => entry['refseq_category']['value'],
          :release_date => entry['release_date']['value'],
          :molecule_name => entry['replicon_type']['value'],
          :refseq_id => entry['seq_id']['value'],
          :relation_to_type_material => entry['relation_to_type_material']['value']
         }
end

# kingdom の種類によって対象とならない genome データがあるので、
# assembly report の tax_uri から kindgom 情報を収集し、フィルタリングする
# 元はSPARQLで記述できていたが 以下のエラーが除去できなかったためスクリプトでフィルタリング
# 'Virtuoso 42000 Error TN...: Exceeded 1000000000 bytes in transitive temp memory.  use t_distinct, t_max or more T_M'
tax_list = list.map{|row| row[:tax_id]}.uniq
template = File.read("#{base_dir}/sparql/tax_lineage.erb")
kingdom_list = ["2", "2157", "10239", "2759"]
tax_kingom = {}
tax_list.each do |tax_id|
  sparql = ERB.new(template).result(binding)
  result = ""

  endpoint.query(sparql, :format => 'json') do |json|
    result += json
  end
  results = JSON.parse(result)["results"]["bindings"]
  kingdom_list.each do |kingdom_tax_id|
    if results.select{|row| row["ancestor_tax"]["value"].split("/").last == kingdom_tax_id}.size > 0
      tax_kingom[tax_id] = kingdom_tax_id
      break;
    end 
  end
  tax_kingom
end


# 真核でない生物種で、relation_to_type_material の情報がないものは対象外とする
# 但し、additional_refseq_list.json で追加したものは削除しない
list.each do |genome|
  if tax_kingom[genome[:tax_id]] != "2759" && genome[:relation_to_type_material] == "na" && (!additional_refseq_list.include?(genome[:assembly_accession]))
    genome[:delete_flag] = true
  end
end
list.delete_if {|row| row[:delete_flag] == true }

puts JSON.pretty_generate(list.uniq)
