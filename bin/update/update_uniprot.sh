#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
### Create and load tgup(TogoGenome + UniProt)
echo "Start: Update tgup"
rake uniprot:refseq2up $1
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:refseq2up"
rake uniprot:load_tgup
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:load_tgup"
echo "End: Update tgup"

### Convert (RDF/XML=>Turtle) and load UniProt
echo "Start: Update UniProt"
rake uniprot:download_rdf
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:download_rdf"
rake uniprot:load $1
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:load"
rake uniprot:uniprot2stats
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:uniprot2stats"
rake uniprot:load_stats
ruby ${script_dir}/../checker/check.rb $1 $2 "uniprot:load_stats"
echo "End: Update UniProt"
