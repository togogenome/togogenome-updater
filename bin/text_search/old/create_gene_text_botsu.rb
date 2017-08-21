#!/usr/bin/env ruby

require 'json'
require 'fileutils'


ISQL = '/data/store/virtuoso7.1/bin/isql 20711 dba dba'
ISQL_OPT = 'VERBOSE=OFF BANNER=OFF PROMPT=OFF ECHO=OFF BLOBS=ON ERRORS=stdout'
PREFIX = '/data/store/rdf/togogenome/bin/text_search/gene'
OUTPUT_DIR = '/data/store/rdf/togogenome/text_search/current/prepare/gene'
PROTEIN_GENE_JSON = "#{OUTPUT_DIR}/json/protein_gene.json"
TOGO_UP_JSON = "#{OUTPUT_DIR}/json/togo_uniprot.json"

GENE_ATTRIBUTES = 'gene_attributes'
PROTEIN_REFERENCES = 'protein_references'
PROTEIN_CROSS_REFERENCES = 'protein_cross_references'
PROTEIN_SEQUENCE_ANNOTANION = 'protein_sequence_annotation'
PROTEIN_NAMES_GENE_NAMES = 'protein_names_gene_name'
PROTEIN_NAMES_SUMMARY = 'protein_names_summary'
PROTEIN_ONTOLOGIES_KEYWORDS = 'protein_ontologies_keywords'
PROTEIN_ONTOLOGIES_GO = 'protein_ontologies_go'

def isql_query(query_name)
  $stderr.puts("Start: " + query_name)
  query_file = "#{PREFIX}/sparql/#{query_name}.rq"
  output_file = "#{OUTPUT_DIR}/text/#{query_name}.txt"
  start_time = Time.now
  system(%Q[#{ISQL} #{ISQL_OPT} < #{query_file} > #{output_file}])
  times = "Time: #{Time.now - start_time}s"
  $stderr.puts("End: " + query_name)
  $stderr.puts(times)
end

def output_json(stanza_name, query_names)
  start_time = Time.now
  output_file  = "#{OUTPUT_DIR}/json/#{stanza_name}.json" 
  STDERR.puts stanza_name
  if @protein_gene_map == nil
    @protein_gene_map = JSON.parse(File.read("#{PROTEIN_GENE_JSON}"))
    STDERR.puts('End create protein-gene map')
  end
  result_array = [] 
  added_gene_id = {}
  query_names.each do |query_name|
    File.open("#{OUTPUT_DIR}/text/#{query_name}.txt") do |f|
      cnt = 0
      start_rap_time = Time.now
      while line  = f.gets
        if query_name.start_with?('gene')
          result_array.push(gene_obj_mapping(line, query_name))
        elsif query_name.start_with?('protein')
          protein_info = protein_obj_mapping(line, query_name)
          next if @protein_gene_map[protein_info.keys.first] == nil
          @protein_gene_map[protein_info.keys.first].each do |gene_id|
            if added_gene_id[gene_id] == nil
              result_array.push({"@id" => gene_id, "values" => protein_info}) 
              added_gene_id[gene_id] = true
            else # has already added gene
              result_array.each do |gene|
                if gene["@id"] == gene_id
                  protein_info[protein_info.keys.first].each do |column|
                    if gene["values"][column] == nil
                      gene["values"][column] = protein_info[protein_info.keys.first][column]
                    else
                      gene["values"][column] += "," + protein_info[protein_info.keys.first][column]
                    end
                  end
                end
              end
            end
          end
        end
        cnt += 1
        if((cnt % 100000) == 0)
          rap_time = "Time: #{Time.now - start_rap_time}s"
          STDERR.puts cnt.to_s + " " + rap_time
          start_rap_time = Time.now
        end
      end
      File.open("#{output_file}", 'w') do |file|
        file.puts JSON.pretty_generate(result_array)
      end
    end
  end
  times = "Time: #{Time.now - start_time}s"
  STDERR.puts stanza_name
  STDERR.puts times
end

def to_utf(str)
  str.force_encoding('UTF-8')
end

def gene_obj_mapping(line, query_name)
  return line.start_with?('http://togogenome.org/gene/') unless
  columns = line.split('^@')
  gene_id = columns[0].strip.gsub('http://togogenome.org/gene/','')

  case query_name
  when GENE_ATTRIBUTES
    values = { :gene_id => to_utf(gene_id),
               :locus_tags => to_utf(columns[1].strip),
               :gene_names => to_utf(columns[2].strip),
               :sequence_labels => to_utf(columns[3].strip),
               :refseq_labels => to_utf(columns[4].strip),
               :sequence_organism_names => to_utf(columns[5].strip)}
  end
  hash = {"@id" => gene_id, "values" => values}
end

def protein_obj_mapping(line, query_name)
  return line.start_with?('http://purl.uniprot.org/uniprot/') unless
  columns = line.split('^@')
  uniprot_no = columns[0].strip.gsub('http://purl.uniprot.org/uniprot/','')

  case query_name
  when PROTEIN_CROSS_REFERENCES
    xref_ids = columns[3].strip.split('||').map do |uri|
      uri.split('/').last
    end
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_xref_categories => to_utf(columns[1].strip),
               :up_xref_abbrs => to_utf(columns[2].strip),
               :up_xref_ids => to_utf(xref_ids.join(','))}
  when PROTEIN_REFERENCES
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_ref_pubmed_ids => to_utf(columns[1].strip),
               :up_ref_citation_names => to_utf(columns[2].strip),
               :up_ref_citation_titles => to_utf(columns[3].strip),
               :up_ref_citation_authors => to_utf(columns[4].strip)}
  when PROTEIN_SEQUENCE_ANNOTANION
    feature_ids = columns[4].strip.gsub('http://purl.uniprot.org/annotation/','')
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_seq_anno_parent_labels => to_utf(columns[1].strip),
               :up_seq_anno_labels => to_utf(columns[2].strip),
               :up_seq_anno_comments => to_utf(columns[3].strip),
               :up_seq_anno_feature_ids => to_utf(feature_ids) }
  when PROTEIN_NAMES_GENE_NAMES
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_gene_names => to_utf(columns[1].strip),
               :up_synonyms_names => to_utf(columns[2].strip),
               :up_locus_tags => to_utf(columns[3].strip),
               :up_orf_names => to_utf(columns[4].strip)}
  when PROTEIN_NAMES_SUMMARY
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_recommended_names => to_utf(columns[1].strip),
               :up_ec_names => to_utf(columns[2].strip),
               :up_alternative_names => to_utf(columns[3].strip)}
  when PROTEIN_ONTOLOGIES_KEYWORDS
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_keyword_root_names => to_utf(columns[1].strip),
               :up_keyword_names => to_utf(columns[2].strip)}
  when PROTEIN_ONTOLOGIES_GO
    values = { :uniprot_id => to_utf(uniprot_no),
               :up_go_names => to_utf(columns[1].strip)}
  end
  result_hash = {uniprot_no => values}
end

def protein2gene (stanza_name, query_names)
  output_file  = "#{OUTPUT_DIR}/json/#{stanza_name}_index.json"  
  if @gene_up_map == nil
    @gene_up_map = JSON.parse(File.read("#{TOGO_UP_JSON}"))
    STDERR.puts('End create gene up map')
    gene_id_list = @gene_up_map.keys
    STDERR.puts('End create gene id list')
  end
  result = []
  query_names.each do |query_name|
    $stderr.puts("start:#{query_name}")
    up_text_data = JSON.parse(File.read("#{OUTPUT_DIR}/json/#{query_name}.json"))
    $stderr.puts("readed#{query_name}")
    gene_id_list.each do |gene_id|
      protein_info = {}
      @gene_up_map[gene_id].each do |uniprot_id|
        unless up_text_data[uniprot_id].nil?
          up_text_data[uniprot_id].keys.each do |column|
            if protein_info[column] == nil
              protein_info[column] = up_text_data[uniprot_id][column]
            else
              protein_info[column] += "," + up_text_data[uniprot_id][column]
            end
          end
        end
      end
      protein_info["gene_id"] = gene_id
      hash = {"@id" => gene_id, "values" => protein_info}
      result.push(hash)    
    end
  end
  $stderr.puts("start:output json")
  File.open("#{output_file}", 'w') do |file|
    file.puts JSON.pretty_generate(result)
  end
end

#isql_query(PROTEIN_CROSS_REFERENCES)
#output_json(PROTEIN_CROSS_REFERENCES)
#Time: 5843s + 766s 1h 50min

#isql_query(PROTEIN_REFERENCES)
#output_json(PROTEIN_REFERENCES)
#Time: 1h 45min

#isql_query(PROTEIN_NAMES_GENE_NAMES)
#output_json(PROTEIN_NAMES_GENE_NAMES)
#Time: 494s + 589s 18min

#isql_query(PROTEIN_NAMES_SUMMARY)
#output_json(PROTEIN_NAMES_SUMMARY)
#Time: 15min 
query_names = [PROTEIN_NAMES_GENE_NAMES,PROTEIN_NAMES_SUMMARY]
output_json('protein_names', query_names)

#isql_query(PROTEIN_SEQUENCE_ANNOTANION)
#output_json(PROTEIN_SEQUENCE_ANNOTANION)
#Time: 12113s + 843s 3h 36min 

#isql_query(PROTEIN_ONTOLOGIES_KEYWORDS)
#output_json(PROTEIN_ONTOLOGIES_KEYWORDS)
#Time: 766s + 4003s 1h 20min

#isql_query(PROTEIN_ONTOLOGIES_GO)
#output_json(PROTEIN_ONTOLOGIES_GO)
#Time: 282s + 209s 8min

#isql_query(GENE_ATTRIBUTES)
#output_json(GENE_ATTRIBUTES)
#Time: 925s + 12316s 3h 40min
#Time: 925s + 3663s 1h 18min

#query_names = [PROTEIN_NAMES_GENE_NAMES, PROTEIN_NAMES_SUMMARY]
#protein2gene('protein_names', query_names)
# 18min mem 61G
