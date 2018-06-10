#!/usr/bin/env ruby

require 'rubygems'
require 'bio'
require 'json'
require 'fileutils'

SEQ_CHUNK_SIZE = 20000

OUTPUT_DIR = "refseq/current/jbrowse_upd"

ENDPOINT = "http://dev.togogenome.org/sparql-app"

GENE_COLOR = <<"GENE_COLOR"
function(feature) {
  var color = "#67b6c9";
  switch (feature.data.so) {
    case "http://purl.obolibrary.org/obo/SO_0000316":
      color = "#8bba30";
      break;
    case "http://purl.obolibrary.org/obo/SO_0000253":
      color = "#ef6391";
      break;
    case "http://purl.obolibrary.org/obo/SO_0000252":
      color = "#e69023";
      break;
  }
  return color;
}
GENE_COLOR

SPARQL_ALL = <<"SPARQL_ALL"
DEFINE sql:select-option "order"

PREFIX rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd:    <http://www.w3.org/2001/XMLSchema#>
PREFIX obo:    <http://purl.obolibrary.org/obo/>
PREFIX sio:    <http://semanticscience.org/resource/>
PREFIX faldo:  <http://biohackathon.org/resource/faldo#>
PREFIX insdc:  <http://ddbj.nig.ac.jp/ontologies/nucleotide/>

SELECT DISTINCT ?gene_id ?gene_type ?gene_start ?gene_end ?feat_id ?feat_type ?feat_start ?feat_end ?exon_id ?exon_type ?exon_start ?exon_end ?strand ?gene_name ?gene_description ?feat_name ?feat_description ?feat_class
FROM <http://togogenome.org/graph/refseq>
FROM <http://togogenome.org/graph/so>
FROM <http://togogenome.org/graph/faldo>
WHERE {

{

SELECT DISTINCT ?gene_id ?gene_type ?gene_start ?gene_end ?feat_id ?feat_type ?feat_start ?feat_end ?exon_id ?exon_type ?exon_start ?exon_end ?strand ?gene_name ?gene_product ?gene_note ?feat_name ?feat_product ?feat_note ?feat_class
WHERE {
  VALUES ?region_start { {start} }
  VALUES ?region_end { {end} }
  ?refseq_id insdc:sequence_version "{ref}" .
  ?refseq_id insdc:sequence ?seq_id .

  ?gene_id obo:so_part_of ?seq_id .
  ?gene_id rdfs:subClassOf obo:SO_0000704 .
  BIND ("gene" AS ?gene_type)
  # FALDO
  ?gene_id faldo:location ?gene_loc .
  ?gene_loc faldo:begin/faldo:position ?gene_start_pos .
  ?gene_loc faldo:end/faldo:position ?gene_end_pos .
  ?gene_loc faldo:begin/rdf:type ?faldo_type .
  FILTER (?faldo_type IN (faldo:ForwardStrandPosition, faldo:ReverseStrandPosition, faldo:BothStrandsPosition))
  BIND (IF (?faldo_type = faldo:ForwardStrandPosition, 1, IF (?faldo_type = faldo:ReverseStrandPosition, -1, 0)) AS ?strand)
  BIND (IF (?faldo_type = faldo:ReverseStrandPosition, ?gene_end_pos, ?gene_start_pos) AS ?gene_start)
  BIND (IF (!(?faldo_type = faldo:ReverseStrandPosition), ?gene_end_pos, ?gene_start_pos) AS ?gene_end)
  FILTER (!(?gene_start > ?region_end || ?gene_end < ?region_start))
  ## CDS, tRNA, rRNA etc. (mRNA in JBrowse)
  ?feat_id obo:so_part_of ?gene_id .
  ?feat_id rdfs:subClassOf ?feat_class .
  FILTER (?feat_class IN (obo:SO_0000316, obo:SO_0000253, obo:SO_0000252)) .  # so:CDS, so:tRNA, so:rRNA
  BIND ("mRNA" AS ?feat_type)
  # FALDO
  ?feat_id faldo:location ?feat_loc .
  ?feat_loc faldo:begin/faldo:position ?feat_start_pos .
  ?feat_loc faldo:end/faldo:position ?feat_end_pos .
  BIND (IF (?faldo_type = faldo:ReverseStrandPosition, ?feat_end_pos, ?feat_start_pos) AS ?feat_start)
  BIND (IF (!(?faldo_type = faldo:ReverseStrandPosition), ?feat_end_pos, ?feat_start_pos) AS ?feat_end)
  ## exon (CDS in JBrowse)
  ?feat_id obo:so_has_part ?exon_uri .
  ?feat_id sio:SIO_000974 ?uuid .            # sio:has-ordered-part
  ?uuid sio:SIO_000628 ?exon_uri .           # sio:referes-to
  ?exon_uri rdfs:subClassOf obo:SO_0000147 . # so:exon
  BIND (IRI(CONCAT(STR(?exon_uri), "-", STR(?uuid))) AS ?exon_id)
  BIND ("CDS" AS ?exon_type)
  # FALDO
  ?exon_uri faldo:location ?exon_loc .
  ?exon_loc faldo:begin/faldo:position ?exon_start_pos .
  ?exon_loc faldo:end/faldo:position ?exon_end_pos .
  BIND (IF (?faldo_type = faldo:ReverseStrandPosition, ?exon_end_pos, ?exon_start_pos) AS ?exon_start)
  BIND (IF (!(?faldo_type = faldo:ReverseStrandPosition), ?exon_end_pos, ?exon_start_pos) AS ?exon_end)
  ## LABEL
  OPTIONAL { ?gene_id rdfs:label ?gene_name . }
  OPTIONAL { ?gene_id insdc:product ?gene_product . }
  OPTIONAL { ?gene_id insdc:note ?gene_note . }
  OPTIONAL { ?feat_id rdfs:label ?feat_name . }
  OPTIONAL { ?feat_id insdc:product ?feat_product . }
  OPTIONAL { ?feat_id insdc:note ?feat_note . }
}

} # end sub-query

  #BIND (IF (BOUND(?gene_product), ?gene_product, IF (BOUND(?gene_note), ?gene_note, "") ) AS ?gene_description)
  BIND (COALESCE(?gene_product, ?gene_note, "") AS ?gene_description)
  #BIND (IF (BOUND(?feat_product), ?feat_product, IF (BOUND(?feat_note), ?feat_note, "") ) AS ?feat_description)
  BIND (COALESCE(?feat_product, ?feat_note, "") AS ?feat_description)
}
SPARQL_ALL

SPARQL = <<"SPARQL"
DEFINE sql:select-option "order"

PREFIX rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd:    <http://www.w3.org/2001/XMLSchema#>
PREFIX obo:    <http://purl.obolibrary.org/obo/>
PREFIX sio:    <http://semanticscience.org/resource/>
PREFIX faldo:  <http://biohackathon.org/resource/faldo#>
PREFIX insdc:  <http://ddbj.nig.ac.jp/ontologies/nucleotide/>

SELECT DISTINCT ?gene_id ?gene_type ?gene_start ?gene_end ?feat_id ?feat_type ?feat_start ?feat_end ?exon_id ?exon_type ?exon_start ?exon_end ?strand ?gene_name ?gene_description ?feat_name ?feat_description
FROM <http://togogenome.org/graph/refseq>
FROM <http://togogenome.org/graph/so>
FROM <http://togogenome.org/graph/faldo>
WHERE {
  {
    SELECT DISTINCT ?gene_id ?gene_type ?gene_start ?gene_end ?feat_id ?feat_type ?feat_start ?feat_end ?exon_id ?exon_type ?exon_start ?exon_end ?strand ?gene_name ?gene_product ?gene_note ?feat_name ?feat_product ?feat_note
    {
      ?refseq_id insdc:sequence_version "{ref}" .
      ?refseq_id insdc:sequence ?seq_id .
      ?gene_id obo:so_part_of ?seq_id .
      ?gene_id rdfs:subClassOf obo:SO_0000704 .
      BIND ("gene" AS ?gene_type)
      ?gene_id faldo:location ?gene_loc .
      ?gene_loc faldo:begin/faldo:position ?gene_start_pos .
      ?gene_loc faldo:end/faldo:position ?gene_end_pos .
      ?gene_loc faldo:begin/rdf:type ?faldo_type .
      FILTER (?faldo_type IN (faldo:ForwardStrandPosition, faldo:ReverseStrandPosition, faldo:BothStrandsPosition))
      BIND (IF (?faldo_type = faldo:ForwardStrandPosition, 1, IF (?faldo_type = faldo:ReverseStrandPosition, -1, 0)) AS ?strand)
      BIND (IF (?faldo_type = faldo:ReverseStrandPosition, ?gene_end_pos, ?gene_start_pos) AS ?gene_start)
      BIND (IF (!(?faldo_type = faldo:ReverseStrandPosition), ?gene_end_pos, ?gene_start_pos) AS ?gene_end)
      FILTER (!(?gene_start > {end} || ?gene_end < {start}))
      ?feat_id obo:so_part_of ?gene_id .
      ?feat_id rdfs:subClassOf %SO% .
      BIND ("mRNA" AS ?feat_type)
      ?feat_id faldo:location ?feat_loc .
      ?feat_loc faldo:begin/faldo:position ?feat_start_pos .
      ?feat_loc faldo:end/faldo:position ?feat_end_pos .
      BIND (IF (?faldo_type = faldo:ReverseStrandPosition, ?feat_end_pos, ?feat_start_pos) AS ?feat_start)
      BIND (IF (!(?faldo_type = faldo:ReverseStrandPosition), ?feat_end_pos, ?feat_start_pos) AS ?feat_end)
      ?feat_id obo:so_has_part ?exon_uri .
      ?feat_id sio:SIO_000974 ?uuid .
      ?uuid sio:SIO_000628 ?exon_uri .
      ?exon_uri rdfs:subClassOf obo:SO_0000147 .
      BIND (IRI(CONCAT(STR(?exon_uri), "-", STR(?uuid))) AS ?exon_id)
      BIND ("CDS" AS ?exon_type)
      ?exon_uri faldo:location ?exon_loc .
      ?exon_loc faldo:begin/faldo:position ?exon_start_pos .
      ?exon_loc faldo:end/faldo:position ?exon_end_pos .
      BIND (IF (?faldo_type = faldo:ReverseStrandPosition, ?exon_end_pos, ?exon_start_pos) AS ?exon_start)
      BIND (IF (!(?faldo_type = faldo:ReverseStrandPosition), ?exon_end_pos, ?exon_start_pos) AS ?exon_end)
      OPTIONAL { ?gene_id rdfs:label ?gene_name . }
      OPTIONAL { ?gene_id insdc:product ?gene_product . }
      OPTIONAL { ?gene_id insdc:note ?gene_note . }
      OPTIONAL { ?feat_id rdfs:label ?feat_name . }
      OPTIONAL { ?feat_id insdc:product ?feat_product . }
      OPTIONAL { ?feat_id insdc:note ?feat_note . }
    }
  }
  BIND (COALESCE(?gene_product, ?gene_note, "") AS ?gene_description)
  BIND (COALESCE(?feat_product, ?feat_note, "") AS ?feat_description)
}
SPARQL

=begin
color:    light RGB / dark RGB
blue:    74 180 197 /  52 159 181 : #4ab4c5 / #349fb5
orange: 230 144  35 / 235 121  32 : #e69023 / #eb7920
green:  139 186  48 / 113 170  37 : #8bba30 / #71aa25
pink:   239  99 145 / 240  71 118 : #ef6391 / #f04776
brown:  201 127  68 / 188  99  47 : #c97f44 / #bc632f
purple: 147  87 156 / 122  63 132 : #93579c / #7a3f84

obo:SO_0000316 CDS
obo:SO_0000253 tRNA
obo:SO_0000252 rRNA
obo:SO_0000147 exon
=end

#      "pinned": true,

TRACK_LIST = <<"TRACK_LIST"
{
  "defaultLocation": "1..50000",
  "tracks" : [
    {
      "label" : "DNA",
      "key" : "DNA",
      "type" : "SequenceTrack",
      "chunkSize" : 20000,
      "urlTemplate" : "seq/{refseq}/",
      "metadata": {
        "Category": "Reference sequence"
      }
    },
    {
      "label": "gene",
      "key": "Gene",
      "storeClass": "JBrowse/Store/SeqFeature/TogoGenomeSPARQL",
      "type": "JBrowse/View/Track/CanvasFeatures",
      "glyph": "JBrowse/View/FeatureGlyph/Gene",
      "style": { "featureScale": 0.0001, "labelScale": 0.0001, "descriptionScale": 0.001, "color": #{GENE_COLOR.inspect} },
      "urlTemplate": "#{ENDPOINT}",
      "queryTemplate": #{SPARQL_ALL.inspect}
    },
    {
      "label": "trna",
      "key": "tRNA",
      "storeClass": "JBrowse/Store/SeqFeature/TogoGenomeSPARQL",
      "type": "JBrowse/View/Track/CanvasFeatures",
      "glyph": "JBrowse/View/FeatureGlyph/Gene",
      "style": { "color": "#ef6391" },
      "urlTemplate": "#{ENDPOINT}",
      "queryTemplate": #{SPARQL.sub('%SO%', 'obo:SO_0000253').inspect}
    },
    {
      "label": "rrna",
      "key": "rRNA",
      "storeClass": "JBrowse/Store/SeqFeature/TogoGenomeSPARQL",
      "type": "JBrowse/View/Track/CanvasFeatures",
      "glyph": "JBrowse/View/FeatureGlyph/Gene",
      "style": { "color": "#e69023" },
      "urlTemplate": "#{ENDPOINT}",
      "queryTemplate": #{SPARQL.sub('%SO%', 'obo:SO_0000252').inspect}
    }
  ]
}
TRACK_LIST


class Seq
  attr_accessor :organism, :length, :taxonomy, :bioproject, :refseq
end

sequences = {}

i = 0
Bio::FlatFile.auto(ARGF).each do |entry|
  if $DEBUG
    break if i > 10
    i += 1
  end

  refseq_id, json, = entry.definition.split(/\s+/, 2)
  if json.size > 0
    hash = JSON.parse(json)
    $stderr.puts hash.inspect
    naseq = entry.naseq

    seq = Seq.new
    seq.taxonomy = hash["taxonomy"]
    seq.bioproject = hash["bioproject"]
    seq.refseq = hash["refseq"]
    seq.organism = hash["definition"]
    seq.length = naseq.length
    sequences[seq.taxonomy] ||= []
    sequences[seq.taxonomy] << seq
    path = "#{OUTPUT_DIR}/#{seq.taxonomy}/seq/#{seq.refseq}"
    FileUtils.mkdir_p(path)
    $stderr.puts "Created #{path} ..."

    count = 0
    rem = naseq.window_search(SEQ_CHUNK_SIZE, SEQ_CHUNK_SIZE) do |subseq|
      File.open("#{path}/#{count}.txt", "w") do |f|
        f.print subseq
      end
      count += 1
    end
    if rem
      File.open("#{path}/#{count}.txt", "w") do |f|
        f.print rem
      end
    else
      File.open("#{path}/#{count}.txt", "w") do |f|
        f.print seq
      end
    end
  end
end

sequences.sort.each do |tax_id, seqs|
  ary = []
  seqs.sort_by{|seq| [seq.bioproject, 1.0/seq.length]}.each do |seq|
    hash = {
      #"name" => "#{seq.organism} #{seq.length}bp #{seq.taxonomy}/#{seq.bioproject}/#{seq.refseq}",
      "name" => "#{seq.refseq}",
      "seqDir" => "seq/#{seq.refseq}",
      "start" => 0,
      "end" => seq.length,
      "length" => seq.length,
      "seqChunkSize" => SEQ_CHUNK_SIZE,
    }
    ary << hash
  end
  path = "#{OUTPUT_DIR}/#{tax_id}/seq/refSeqs.json"
  $stderr.puts "Writing #{path} ..."
  File.open(path, "w") do |file|
    file.puts ary.to_json
  end
  path = "#{OUTPUT_DIR}/#{tax_id}/trackList.json"
  $stderr.puts "Writing #{path} ..."
  File.open(path, "w") do |file|
    #file.puts TRACK_LIST.gsub('%SEQ_VERSIONS%', seqs.map{ |seq| '\\"' + seq.refseq + '\\"' }.join(' '))
    # Because all trackList.json files are same now for all organisms, it can just be copied though...
    file.puts TRACK_LIST
  end
end
