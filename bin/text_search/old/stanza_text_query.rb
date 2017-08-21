#!/usr/bin/env ruby

require 'json'
require 'fileutils'
require 'httpclient'

class StanzaTextQuery
  SORL_SERVER = "http://localhost:8983/solr"
  SORL_PARAM = "&fl=@id&wt=json&indent=true"

  def query_solr (query_json)
    param = JSON.parse(File.read(query_json))
    stanza = param["stanza_name"]
    if stanza == nil || stanza == ""
      ## if http protocol retrun code 400
      $stderr.puts "not specified stanza_name."
      result = { "enabled" => false }
      puts JSON.pretty_generate(result)
      return  
    end

    #construct query url
    req_params = create_request_param(param, stanza)
    if req_params == nil #parameter error
      p req_params
      ## if http protocol retrun code 400
      result = { "enabled" => false }
      puts JSON.pretty_generate(result)
      return
    end

    #query to solr 
    client = HTTPClient.new
    url = "#{SORL_SERVER}/#{stanza}/select"
    response = client.get(url,req_params)
    #response = client.get_content(url)

    #return result
    status_code = response.status
    puts status_code
    if status_code >= 200 && status_code < 300
      results = JSON.parse(response.content)
      count = results["response"]["numFound"]
      url_list = results["response"]["docs"].map do |doc|
        if doc["@id"].start_with?("http://togogenome.org/organism/")
          id = doc["@id"].split("/").last
          "http://togogenome.org/organism/#{id}"
        end
      end
      result = { "enabled" => true, "count" => count, "urls" => url_list }
    else
      result = { "enabled" => false }
    end
    puts JSON.pretty_generate(result)
 
  end

  def create_request_param (param, stanza)
    query_text = parse_query_text(param["query_text"]) #TODO urldecode and parse AND/OR
    if query_text == nil || query_text == ""
      $stderr.puts "not specified query text."
      return nil
    end

    offset = param["offset"]
    offset = 0 if offset == nil

    limit = param["limit"]
    limit = 25 if limit == nil

    # debug
    url = "#{SORL_SERVER}/#{stanza}/select?q=#{query_text}&start=#{offset}&rows=#{limit}#{SORL_PARAM}"
    puts url

    req_param = {"q" => query_text, "start" => offset, "rows" => limit, "fl" => "@id", "wt" => "json", "indent" => true}

  end
  
  def parse_query_text (query_text)
    query_text
  end

end

if ARGV.size < 1
  $stderr.puts 'Usage: stanza_text_query.rb query_param_file'
  $stderr.puts 'expected json format. {"query_text": "query_text", "stanza_name", "stanza name", "offset" : number, "row" : number}'
  exit(1)
end

# search from specified stanza
text_query = StanzaTextQuery.new()
text_query.query_solr(ARGV[0])
