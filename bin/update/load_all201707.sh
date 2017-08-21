#!/bin/sh

### Load ontologies
echo "Start: Load ontologies"
rake ontology:faldo:load 20170713
rake ontology:taxonomy:load 20170713
rake ontology:insdc:load 20170713
rake ontology:obo_go:load 20170713
rake ontology:obo_so:load 20170713
rake ontology:meo:load 0.7
rake ontology:mpo:load 0.7
rake ontology:gmo:load 0.11b
rake ontology:mccv:load 0.94
rake ontology:pdo:load 0.11
rake ontology:pdo:load_lod 20160609
rake ontology:csso:load 0.2
rake ontology:gazetteer:load 20130906
rake ontology:brc:load 20160609
rake ontology:gold:load 20150118
echo "End: Load ontologies"

### Create and load ontologies for facet search(MEO & MPO)
echo "Start: Create and load ontologies for facet search"
rake linkage:load_meo_descendants 0.7
rake linkage:load_mpo_descendants 0.7
echo "End: Create and load ontologies for facet search"


### Load Assembly reports
echo "Start: Load Assembly reports"
rake genomes:load 20170623
echo "End: Load Assenbly reports"

### Load Refseq data
echo "Start: Load Refseq"
rake refseq:load_refseq 82
rake refseq:load_stats 82
echo "End: Load Refseq"
