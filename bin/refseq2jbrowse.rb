#!/usr/bin/env ruby

require 'rubygems'
require 'bio'
require 'json'
require 'fileutils'

SEQ_CHUNK_SIZE = 20000

OUTPUT_DIR = "refseq/current/jbrowse_upd"

ENDPOINT = "http://dev.togogenome.org/sparql-app"

SPARQL = <<"SPARQL"
DEFINE sql:select-option "order"
PREFIX rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
PREFIX rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
PREFIX xsd:    <http://www.w3.org/2001/XMLSchema#>
PREFIX obo:    <http://purl.obolibrary.org/obo/>
PREFIX faldo:  <http://biohackathon.org/resource/faldo#>
PREFIX insdc:   <http://ddbj.nig.ac.jp/ontologies/nucleotide/>

SELECT DISTINCT ?start ?end ?strand ?type ?name ?description ?uniqueID ?parentUniqueID
FROM <http://togogenome.org/graph/refseq>
FROM <http://togogenome.org/graph/so>
FROM <http://togogenome.org/graph/faldo>
WHERE
{
  ?refseq_id insdc:sequence_version "{ref}" .
  ?refseq_id insdc:sequence ?seq_id .
  ?gene_id ?obo_so_part_of ?seq_id .
  ?parentUniqueID ?obo_so_part_of ?gene_id .
  ?parentUniqueID rdfs:subClassOf ?parentUniqueID_type FILTER ( ?parentUniqueID_type = %SO% ).
  ?parentUniqueID obo:so_has_part ?uniqueID .
  ?parentUniqueID_type rdfs:label ?parentUniqueID_type_label .
  BIND ( str(?parentUniqueID_type_label) as ?type ) .
  ?uniqueID rdfs:subClassOf ?uniqueID_type FILTER ( ?uniqueID_type IN( obo:SO_0000147 ) ).
  ?uniqueID faldo:location ?loc .
  ?loc faldo:begin/faldo:position ?pos_start .
  ?loc faldo:end/faldo:position ?pos_end .
  ?loc faldo:begin/rdf:type ?faldo_type FILTER ( ?faldo_type IN (faldo:ForwardStrandPosition, faldo:ReverseStrandPosition, faldo:BothStrandsPosition) ).
  BIND ( IF (?faldo_type = faldo:ForwardStrandPosition, 1, if(?faldo_type= faldo:ReverseStrandPosition, -1, 0)) as ?strand ) .
  BIND ( IF (?faldo_type = faldo:ReverseStrandPosition, ?pos_end, ?pos_start ) AS ?start ).
  BIND ( IF (!(?faldo_type = faldo:ReverseStrandPosition), ?pos_end , ?pos_start) AS ?end ).
  FILTER ( !(?start > {end} || ?end < {start}) )
  OPTIONAL { ?parentUniqueID rdfs:label ?name . }
  OPTIONAL { ?parentUniqueID insdc:product ?description . }
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
      "label": "cds",
      "key": "CDS",
      "storeClass": "JBrowse/Store/SeqFeature/SPARQL",
      "type": "CanvasFeatures",
      "style": { "className": "transcript", "color": "#8bba30" },
      "urlTemplate": "#{ENDPOINT}",
      "queryTemplate": #{SPARQL.sub('%SO%', 'obo:SO_0000316').inspect}
    },
    {
      "label": "trna",
      "key": "tRNA",
      "storeClass": "JBrowse/Store/SeqFeature/SPARQL",
      "type": "CanvasFeatures",
      "style": { "className": "transcript", "color": "#ef6391" },
      "urlTemplate": "#{ENDPOINT}",
      "queryTemplate": #{SPARQL.sub('%SO%', 'obo:SO_0000253').inspect}
    },
    {
      "label": "rrna",
      "key": "rRNA",
      "storeClass": "JBrowse/Store/SeqFeature/SPARQL",
      "type": "CanvasFeatures",
      "style": { "className": "transcript", "color": "#e69023" },
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
    file.puts TRACK_LIST.gsub('%SEQ_VERSIONS%', seqs.map{ |seq| '\\"' + seq.refseq + '\\"' }.join(' '))
  end
end
