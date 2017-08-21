SPARQL
DEFINE sql:select-option "order"
PREFIX up: <http://purl.uniprot.org/core/>
SELECT COUNT(DISTINCT ?togo_gene)
WHERE {
  GRAPH <http://togogenome.org/graph/tgtax>
  {
    ?taxonomy_id rdfs:subClassOf <http://identifiers.org/taxonomy/1>
  }
  GRAPH <http://togogenome.org/graph/taxonomy>
  {
    ?taxonomy_id rdfs:label ?taxonomy_name .
  }
  GRAPH <http://togogenome.org/graph/tgup> {
  ?togo_gene rdfs:seeAlso ?taxonomy_id .
  ?togo_gene skos:exactMatch ?refseq_gene .
  ?togo_gene rdfs:seeAlso ?id_uniprot .
  ?id_uniprot a <http://identifiers.org/uniprot> . 
  ?id_uniprot rdfs:seeAlso ?uniprot.
  }
  GRAPH <http://togogenome.org/graph/uniprot> {
  ?uniprot a up:Protein
 }
}
;
#usage: 71.sh < create_protein_list.sql > protein_list.txt 
