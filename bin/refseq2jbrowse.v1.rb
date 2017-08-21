#!/usr/bin/env ruby

require 'rubygems'
require 'bio'
require 'json'
require 'fileutils'

SEQ_CHUNK_SIZE = 20000

OUTPUT_DIR = "refseq/current/jbrowse"

SPARQL_CDS = <<"SPARQL_CDS"
DEFINE sql:select-option "order"

prefix rdf:    <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs:   <http://www.w3.org/2000/01/rdf-schema#>
prefix xsd:    <http://www.w3.org/2001/XMLSchema#>
prefix obo:    <http://purl.obolibrary.org/obo/>
prefix faldo:  <http://biohackathon.org/resource/faldo#>
prefix idorg:  <http://rdf.identifiers.org/database/>
prefix insdc:  <http://insdc.org/owl/>

select ?start,
       ?end,
       IF( ?faldo_type = faldo:ForwardStrandPosition,
           1,
           IF( ?faldo_type = faldo:ReverseStrandPosition,
               -1,
                0
             )
         ) as ?strand,
       str(?obj_type_name) as ?type,
       str(?label) as ?name,
       str(?obj_name) as ?description,
       ?obj as ?uniqueID,
       ?parent as ?parentUniqueID
from <http://togogenome.org/refseq/>
from <http://togogenome.org/so/>
from <http://togogenome.org/faldo/>
  where {

  values ?faldo_type { faldo:ForwardStrandPosition faldo:ReverseStrandPosition faldo:BothStrandsPosition }
  values ?refseq_label { "{ref}" }
  #values ?obj_type {  obo:SO_0000704 }
  ?obj obo:so_part_of ?parent . filter( ?obj_type = obo:SO_0000704 || ?parent != ?seq )

  # on reference sequence
  ?obj obo:so_part_of+  ?seq .
  ?seq a ?seq_type.
  ?seq_type rdfs:label ?seq_type_label.
  ?seq rdfs:seeAlso ?refseq .
  ?refseq a idorg:RefSeq .
  ?refseq rdfs:label ?refseq_label .

  # get faldo begin and end
  ?obj faldo:location ?faldo .
  ?faldo faldo:begin/rdf:type ?faldo_type .
  ?faldo faldo:begin/faldo:position ?start .
  ?faldo faldo:end/faldo:position ?end .
  filter ( !(?start > {end} || ?end < {start}) )

  # feature type
  ?obj rdf:type ?obj_type .
  ?obj_type rdfs:label ?obj_type_name .
  optional {
    ?obj insdc:feature_locus_tag ?label .
}

  # feature name is the feature product
optional {
    ?obj insdc:feature_product ?obj_name .
}

#optional {
  #  ?obj rdfs:seeAlso ?obj_seealso .
#}

}
SPARQL_CDS

SPARQL_tRNA = <<"SPARQL_tRNA"
SPARQL_tRNA

SPARQL_rRNA = <<"SPARQL_rRNA"
SPARQL_rRNA

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
      "glyph": "JBrowse/View/FeatureGlyph/ProcessedTranscript",
      "urlTemplate": "http://ep.dbcls.jp/sparql7",
      "style": { "className": "transcript" },
      "queryTemplate": #{SPARQL_CDS.inspect}
    },
  ]
}
TRACK_LIST


class Seq
  attr_accessor :organism, :length, :taxonomy, :bioproject, :refseq
end

sequences = {}

Bio::FlatFile.auto(ARGF).each do |entry|
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
      "name" => "#{seq.organism} #{seq.length}bp #{seq.taxonomy}/#{seq.bioproject}/#{seq.refseq}",
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
    file.puts TRACK_LIST
  end
end

# map rs taxonomy ids -> up taxonomy + up subtree?

