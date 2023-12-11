#!/usr/bin/env ruby
require 'tempfile'

class SparqlIsql
  def self.isql_query(isql_cmd, sparql, output_path = nil)

    sparql_path = Tempfile.open('sparql_file') {|fp|
      fp.puts "SPARQL"
      fp.puts sparql
      fp.puts ";"
      fp.path
    }

    if output_path
      system(%Q[#{isql_cmd} < #{sparql_path} > #{output_path}])
    else
      output_tmp = Tempfile.open('output')
      system(%Q[#{isql_cmd} < #{sparql_path} > #{output_tmp.path}])
      result = output_tmp.read
      output_tmp.close!
      result
    end
  end
  
end