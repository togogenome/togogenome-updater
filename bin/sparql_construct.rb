#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'cgi'
require 'httpclient'

endpoint = ARGV.shift
file = ARGV.shift

sparql = File.read(file)

client = HTTPClient.new
header = { 'Accept' => 'text/turtle' }
query = { 'query' => CGI.escape(sparql)}
url = endpoint + '?query=' + CGI.escape(sparql)
result = client.get_content(url, nil, header)
puts result
