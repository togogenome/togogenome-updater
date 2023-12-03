#!/usr/bin/env ruby

require 'rubygems'
require 'fileutils'
require 'cgi'

endpoint = ARGV.shift
file = ARGV.shift

sparql = File.read(file)
url = "#{endpoint}?query=#{CGI.escape(sparql)}"
system("curl #{url}")

# docker composeのservice名によるアクセスでは(virtuoso:8890 )エラーになる為断念
# HT059: Proxy access to virtuoso:8890 denied due to access control
#Net::HTTP.start(uri.host, uri.port) do |http|
#  request = Net::HTTP::Get.new(url)
#  request['Accept'] = 'text/turtle'
#  response = http.request(request)
#  puts response.body
#end
