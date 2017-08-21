#!/usr/bin/env ruby

require "rubygems"
require "sequel"

class SPARQL_ODBC
  PROTEIN_REFERENCES = 'protein_references'
  PROTEIN_CROSS_REFERENCES = 'protein_cross_references'
  PROTEIN_SEQUENCE_ANNOTANION = 'protein_sequence_annotation'
  PROTEIN_NAMES_GENE_NAMES = 'protein_names_gene_name'
  PROTEIN_NAMES_SUMMARY = 'protein_names_summary'
  PROTEIN_ONTOLOGIES_KEYWORDS = 'protein_ontologies_keywords'
  PROTEIN_ONTOLOGIES_GO = 'protein_ontologies_go'
  GENE_ATTRIBUTES = 'gene_attributes'

  # db_name is defined at /etc/odbc.ini or ~/.odbc.ini"
  def initialize(odbc_db_name, user, password)
    @db_name = odbc_db_name
    @user = user
    @pass = password
#    connect()
  end

  def connect()
    @conn = Sequel.odbc("#{@db_name}", :user => "#{@user}", :password => "#{@pass}")
  end

  def query(sparql, query_name)
    connect()
    sparql_isql = "SPARQL " + sparql
    result_hash = {}
    cnt = 0
    @conn["#{sparql_isql}"].each do |row|
   # @conn.fetch("#{sparql_isql}") do |row|
      if query_name.start_with?('protein')
        key = row[:protein].sub('http://purl.uniprot.org/uniprot/','')
      elsif query_name.start_with?('gene')
        key = row[:togo_gene].sub('http://togogenome.org/gene/','')      
      else
        next
      end
    
      result_hash[key] = obj_mapping(row, query_name) 
      cnt += 1
      #STDERR.puts cnt.to_s + ' : ' + Time.now.strftime("%Y-%m-%d %H:%M:%S")
      if (cnt % 10000 == 0)
       STDERR.puts (cnt / 10000).to_s + 'man : ' + Time.now.strftime("%Y-%m-%d %H:%M:%S")
      end
    end
    disconnect()
    return result_hash
  end

  def to_utf(str)
    str.force_encoding('UTF-8')
  end
  
  def disconnect()
    @conn.disconnect
    #http://d.hatena.ne.jp/shibason/20100304/1267697379
    Sequel::DATABASES.delete(@conn)
  end
  def obj_mapping(row, query_name)
    # Cut the uri of ID 
    if query_name.start_with?('protein')
      uniprot_no = row[:protein].sub('http://purl.uniprot.org/uniprot/','')
    elsif query_name.start_with?('gene')
      gene_no = row[:togo_gene].sub('http://togogenome.org/gene/','')      
    end
    
    case query_name
    when PROTEIN_CROSS_REFERENCES
      xref_ids = row[:up_xref_uris].split('||').map do |uri|
        uri.split('/').last
      end
      values = { :uniprot_id => to_utf(uniprot_no),
                 :up_xref_categories => to_utf(row[:up_xref_categories]),
                 :up_xref_abbrs => to_utf(row[:up_xref_abbrs]),
                 :up_xref_ids => to_utf(xref_ids.join(','))}
    when PROTEIN_SEQUENCE_ANNOTANION
      feature_ids = row[:up_seq_anno_feature_ids].sub('http://purl.uniprot.org/annotation/','')
      values = { :uniprot_id => to_utf(uniprot_no),
                 :up_seq_anno_parent_labels => to_utf(row[:up_seq_anno_parent_labels]), 
                 :up_seq_anno_labels => to_utf(row[:up_seq_anno_labels]),
                 :up_seq_anno_comments => to_utf(row[:up_seq_anno_comments]), 
                 :up_seq_anno_feature_ids => to_utf(feature_ids) }
    when GENE_ATTRIBUTES
      values = { :gene_id => gene_no,
                 :locus_tags => to_utf(row[:locus_tags]), 
                 :gene_names => to_utf(row[:gene_names]),
                 :sequence_labels => to_utf(row[:sequence_labels]), 
                 :refseq_labels => to_utf(row[:refseq_labels]), 
                 :sequence_organism_names => to_utf(row[:sequence_organism_names])}
=begin
    when PROTEIN_REFERENCES
      values = { :uniprot_no => uniprot_no, :pubmed_ids => to_utf(row[:pubmed_ids]),
                 :citation_names => to_utf(row[:citation_names]),
                 :citation_titles => to_utf(row[:citation_titles]),
                 :citation_authors => to_utf(row[:citation_authors])}
    when PROTEIN_NAMES_GENE_NAMES
      values = { :uniprot_no => uniprot_no,
                 :gene_names => to_utf(row[:gene_names]),
                 :synonyms_names => to_utf(row[:synonyms_names]),
                 :locus_names => to_utf(row[:locus_names]),
                 :orf_names => to_utf(row[:orf_names])}
    when PROTEIN_NAMES_SUMMARY
      values = { :uniprot_no => uniprot_no,
                 :recommended_names => to_utf(row[:recommended_names]),
                 :ec_names => to_utf(row[:ec_names]),
                 :alternative_names => to_utf(row[:alternative_names])}
=end
    else
      values = {}
      row.each do |k, v|
        if k.to_s == "protein" 
          values["uniprot_id"] = uniprot_no 
        else
          values[k] = to_utf(v)
        end
      end
    end
    values
  end
end

