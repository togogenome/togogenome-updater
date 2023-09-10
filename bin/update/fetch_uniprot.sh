#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
### Fetch UniProt data and create RDF/XML file
echo "Start Fetch Uniprot"
rake uniprot:fetch $1
rake uniprot:unzip
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:unzip"
echo "End Fetch Uniprot"

