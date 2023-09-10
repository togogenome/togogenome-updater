#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
### Generate and load rdf for facet search
echo "Start: Update rdf for facet search"
rake linkage:goup
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:goup"
rake linkage:load_goup
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:load_goup"

rake linkage:tgtax
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:tgtax"
rake linkage:load_tgtax
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:load_tgtax"

rake linkage:gotax
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:gotax"
rake linkage:load_gotax
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:load_gotax"

rake linkage:taxonomy_lite
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:taxonomy_lite"
rake linkage:load_taxonomy_lite
ruby ${script_dir}/../checker/check.rb $1 $2 "linkage:load_taxonomy_lite"
echo "End: Update rdf for faset search"
