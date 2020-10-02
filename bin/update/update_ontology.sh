#!/bin/sh

### Fetch daily update ontology files 
echo "Start: Fetch ontologies"
rake ontology:faldo:fetch
rake ontology:taxonomy:fetch
rake ontology:insdc:fetch
rake ontology:obo_go:fetch
echo "End: Fetch ontologies"
echo `date "+%Y-%m-%d %H:%M:%S"`" End: Fetch ontologies" > "update.log"

### Load ontologies
echo "Start: Load ontologies"
rake ontology:faldo:load 20170713
rake ontology:taxonomy:load 20170713
rake ontology:insdc:load 20170713
rake ontology:obo_go:load 20170713
rake ontology:obo_so:load 20170713
rake ontology:meo:load 0.7
rake ontology:meo_dag:load 0.9
rake ontology:mpo:load 0.7
rake ontology:gmo:load 0.11b
rake ontology:mccv:load 0.99
rake ontology:pdo:load 0.11
rake ontology:pdo:load_lod 20160609
rake ontology:csso:load 0.2
rake ontology:gazetteer:load 20130906
rake ontology:brc:load 20160609
rake ontology:nbrc:load 20200229
rake ontology:jcm:load 20200229
rake ontology:gold:load 20150118
echo "End: Load ontologies"
echo `date "+%Y-%m-%d %H:%M:%S"`" End: Load ontologies" >> "update.log"

### Create and load ontologies for facet search(MEO & MPO)
echo "Start: Create and load ontologies for facet search"
rake linkage:meo_descendants
rake linkage:mpo_descendants
rake linkage:load_meo_descendants 0.7
rake linkage:load_mpo_descendants 0.7
echo "End: Create and load ontologies for facet search"
