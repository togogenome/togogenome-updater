#!/bin/sh

if [ $1 == "-dev" ] ; then
  SOLR_URL="http://localhost:15963/solr"
else
  SOLR_URL="http://togogenome.org/solr"
fi

##environment
wget -O result/environment_attributes.json "${SOLR_URL}/environment_attributes/select?q=text:spring OR id_text:spring&wt=json&indent=true"
wget -O result/environment_inhabitants.json "${SOLR_URL}/environment_inhabitants/select?q=text:ATCC OR id_text:ATCC&wt=json&indent=true"

##organism
wget -O result/genome_cross_references.json "${SOLR_URL}/genome_cross_references/select?q=text:NC_018145.1 OR id_text:NC_018145.1&wt=json&indent=true"
wget -O result/organism_cross_references.json "${SOLR_URL}/organism_cross_references/select?q=text:Gc00168 OR id_text:Gc00168&wt=json&indent=true"
wget -O result/organism_culture_collections.json "${SOLR_URL}/organism_culture_collections/select?q=text:Streptomyces OR id_text:Streptomyces&wt=json&indent=true"
wget -O result/organism_medium_information.json "${SOLR_URL}/organism_medium_information/select?q=text:Yeast OR id_text:Yeast&wt=json&indent=true"
wget -O result/organism_names.json "${SOLR_URL}/organism_names/select?q=text:Nostoc OR id_text:Nostoc&wt=json&indent=true"
wget -O result/organism_pathogen_information.json "${SOLR_URL}/organism_pathogen_information/select?q=text:melitensis OR id_text:melitensis&wt=json&indent=true"
wget -O result/organism_phenotype.json "${SOLR_URL}/organism_phenotype/select?q=text:Mesophilic OR id_text:Mesophilic&wt=json&indent=true"

##gene
wget -O result/gene_attributes.json "${SOLR_URL}/gene_attributes/select?q=text:HOXD8 OR id_text:HOXD8&wt=json&indent=true"
wget -O result/protein_cross_references.json "${SOLR_URL}/protein_cross_references/select?q=text:P16591 OR id_text:P16591&wt=json&indent=true"
wget -O result/protein_names.json "${SOLR_URL}/protein_names/select?q=text:PGR12 OR id_text:PGR12&wt=json&indent=true"
wget -O result/protein_ontologies.json "${SOLR_URL}/protein_ontologies/select?q=text:transmembrane OR id_text:transmembrane&wt=json&indent=true"
wget -O result/protein_references.json "${SOLR_URL}/protein_references/select?q=text:cyanobacterium OR id_text:cyanobacterium&wt=json&indent=true"
wget -O result/protein_sequence_annotation.json "${SOLR_URL}/protein_sequence_annotation/select?q=text:carboxylate OR id_text:carboxylate&wt=json&indent=true"



##other
#wget -O result.json "http://dev.togogenome.org/solr/gene_attributes/select?q=text:MTR_4g072540 OR id_text:MTR_4g072540&wt=json&indent=true"
#wget -O result.json "http://dev.togogenome.org/solr/gene_attributes/select?q=text:chromosome OR id_text:chromosome&wt=json&indent=true"
#wget -O result.json "http://dev.togogenome.org/solr/protein_cross_references/select?q=text:CCDS4923.1 OR id_text:CCDS4923.1&wt=json&indent=true"
#wget -O result.json "http://dev.togogenome.org/solr/protein_names/select?q=text:protein OR id_text:protein&wt=json&indent=true"
