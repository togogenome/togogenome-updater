#!/usr/bin/env ruby

require 'rubygems'
require 'json/ld'
require 'fileutils'
require 'rdf/turtle'

#jsonld = "meo.jsonld"
#jsonld = "meo_invalid.jsonld"
#jsonld = "meo_text.jsonld"
#jsonld = "environment_inhabitants.jsonld"
#jsonld = "environment_inhabitants_no_context.jsonld"
#jsonld = "environment_inhabitants_each_context.jsonld"
#jsonld = "environment_inhabitants_auto.jsonld"
#jsonld = "genome_cross_reference.jsonld"
jsonld = "environment_inhabitants_array.jsonld"

input = JSON.parse(File.read("#{jsonld}"))

#puts JSON::LD::API.expand(input)
graph = RDF::Graph.new << JSON::LD::API.toRdf(input)
#puts graph.dump(:ttl, prefixes: {foaf: "http://xmlns.com/foaf/0.1/"})
prefix = { prefixes: {env: "http://togogenome.org/environment/",
                      env_txt: "http://togogenome.org/environment/text/"}}
puts graph.dump(:ttl, prefix)
