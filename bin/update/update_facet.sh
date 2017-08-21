#!/bin/sh

### Generate and load rdf for facet search
echo "Start: Update rdf for facet search"
rake linkage:goup
rake linkage:load_goup
rake linkage:tgtax
rake linkage:load_tgtax
rake linkage:gotax
rake linkage:load_gotax
rake linkage:taxonomy_lite
rake linkage:load_taxonomy_lite
echo "End: Update rdf for faset search"
