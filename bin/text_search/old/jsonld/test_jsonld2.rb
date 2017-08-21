#!/usr/bin/env ruby

require 'rubygems'
require 'json/ld'
jsonld = File.read("")
input = JSON.parse(File.read("#{jsonld}"))
#input = JSON.parse %(jsonld)
# {
#  "@id": "http://togogenome.org/environment/MEO_0000618",
#  "http://hogehoge/meo_id": "MEO_0000618" 
# }
#)
puts JSON::LD::API.expand(input)
