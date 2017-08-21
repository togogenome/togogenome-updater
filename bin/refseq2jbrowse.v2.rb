#!/usr/bin/env ruby

require 'rubygems'
require 'bio'
require 'json'
require 'fileutils'

SEQ_CHUNK_SIZE = 20000

OUTPUT_DIR = "refseq/current/jbrowse"

SPARQL = <<"SPARQL"
DEFINE sql:select-option "order"

prefix rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
prefix xsd:    <http://www.w3.org/2001/XMLSchema#>
prefix obo:    <http://purl.obolibrary.org/obo/>
prefix faldo:  <http://biohackathon.org/resource/faldo#>
prefix taxo:   <http://ddbj.nig.ac.jp/ontologies/taxonomy#>
prefix seqo:   <http://ddbj.nig.ac.jp/ontologies/sequence#>
prefix insdc:  <http://insdc.org/owl/>
prefix idorg:  <http://rdf.identifiers.org/database/>

select distinct ?start ?end ?strand ?type ?name ?description ?uniqueID ?parentUniqueID
from <http://togogenome.org/graph/refseq/>
from <http://togogenome.org/graph/so/>
from <http://togogenome.org/graph/faldo/>
where
{
  {
    select ?start ?end ?strand ?type ?uniqueID ?parentUniqueID
    where
    {
      values ?seq_version { %SEQ_VERSIONS% }
      values ?faldo_type { faldo:ForwardStrandPosition faldo:ReverseStrandPosition faldo:BothStrandsPosition }
      values ?uniqueID_type { %SO% }

      ?seq_id insdc:sequence_version|seqo:sequence_version ?seq_version .

      ?uniqueID obo:so_part_of+ ?seq_id .
      ?uniqueID rdf:type ?uniqueID_type .
      ?uniqueID_type rdfs:label ?uniqueID_type_label .
      bind ( str(?uniqueID_type_label) as ?type )

      filter ( !(?start > {end} || ?end < {start}) )
      ?uniqueID faldo:location ?loc .
      ?loc faldo:begin/faldo:position ?start .
      ?loc faldo:end/faldo:position ?end .
      ?loc faldo:begin/rdf:type ?faldo_type .
      bind ( if(?faldo_type = faldo:ForwardStrandPosition, 1, if(?faldo_type = faldo:ReverseStrandPosition, -1, 0)) as ?strand )

      ?uniqueID obo:so_part_of ?parentUniqueID .
      filter ( ?parentUniqueID != ?seq_id )
    }
  }
  optional {
    ?uniqueID insdc:feature_locus_tag|seqo:locus_tag ?name .
  }
  optional {
    ?uniqueID insdc:feature_product|seqo:feature_product ?description .
  }
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
=end

TRACK_LIST = <<"TRACK_LIST"
{
  "tracks" : [
    {
      "chunkSize" : 20000,
      "urlTemplate" : "seq/{refseq}/",
      "type" : "SequenceTrack",
      "label" : "DNA",
      "key" : "DNA",
      "metadata": {
        "Category": "Reference sequence"
      }
    },
    {
      "label": 'cds',
      "key": "SPARQL CDS",
      "storeClass": "JBrowse/Store/SeqFeature/SPARQL",
      "type": 'CanvasFeatures',
      "glyph": "JBrowse/View/FeatureGlyph/Gene",
      "urlTemplate": "http://ep.dbcls.jp/sparql7dev",
      "style": { "className": "transcript", "color": "#8bba30" },
      "queryTemplate": #{SPARQL.sub('%SO%', 'obo:SO_0000704 obo:SO_0000316 obo:SO_0000147').inspect}
    },
    {
      "label": 'trna',
      "key": "SPARQL tRNA",
      "storeClass": "JBrowse/Store/SeqFeature/SPARQL",
      "type": 'CanvasFeatures',
      "glyph": "JBrowse/View/FeatureGlyph/Gene",
      "urlTemplate": "http://ep.dbcls.jp/sparql7dev",
      "style": { "className": "transcript", "color": "#ef6391" },
      "queryTemplate": #{SPARQL.sub('%SO%', 'obo:SO_0000253').inspect}
    },
    {
      "label": 'rrna',
      "key": "SPARQL rRNA",
      "storeClass": "JBrowse/Store/SeqFeature/SPARQL",
      "type": 'CanvasFeatures',
      "glyph": "JBrowse/View/FeatureGlyph/Gene",
      "urlTemplate": "http://ep.dbcls.jp/sparql7dev",
      "style": { "className": "transcript", "color": "#e69023" },
      "queryTemplate": #{SPARQL.sub('%SO', 'obo:SO_0000252').inspect}
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
  _, org, param, = /(.*)(\{.*\})/.match(entry.definition).to_a
  if param
    hash = eval(param)          # taxonomy, bioproject, refseq
    $stderr.puts hash.inspect
    naseq = entry.naseq

    seq = Seq.new
    seq.taxonomy = hash[:taxonomy]
    seq.bioproject = hash[:bioproject]
    seq.refseq = hash[:refseq]
    seq.organism = org.strip
    seq.length = naseq.length
    sequences[seq.taxonomy] ||= []
    sequences[seq.taxonomy] << seq
    path = "#{OUTPUT_DIR}/#{seq.taxonomy}/seq/#{seq.refseq}"
    FileUtils.mkdir_p(path)
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
      "name" => "RefSeq:#{seq.refseq}",
      "seqDir" => "seq/#{seq.refseq}",
      "start" => 0,
      "end" => seq.length,
      "length" => seq.length,
      "seqChunkSize" => SEQ_CHUNK_SIZE,
    }
    ary << hash
  end
  File.open("#{OUTPUT_DIR}/#{tax_id}/seq/refSeqs.json", "w") do |file|
    file.puts ary.to_json
  end
  File.open("#{OUTPUT_DIR}/#{tax_id}/trackList.json", "w") do |file|
    file.puts TRACK_LIST.gsub('%SEQ_VERSIONS%', seqs.map{ |seq| '\\"' + seq.refseq + '\\"' }.join(' '))
  end
end

# map rs taxonomy ids -> up taxonomy + up subtree?

