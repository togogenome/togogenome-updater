#!/bin/sh
set -eu

# usage
# ./update_all.sh 2015_11    #only update uniprot
# ./update_all.sh 2015_11 73 #update uniprot and refseq

prefix="/data/store/rdf/togogenome/bin/update"

if [ $# -lt 1 ]; then
  echo "USAGE: update_all.sh uniprot_version [refseq_version]"
  exit 1
fi
uniprot_ver=$1
refseq_ver=$2

echo "Start Update All"

. ${prefix}/update_ontology.sh
. ${prefix}/fetch_uniprot.sh $uniprot_ver $refseq_ver &
. ${prefix}/update_refseq.sh $uniprot_ver $refseq_ver
wait;

. ${prefix}/update_fasta_jbrowse.sh $uniprot_ver $refseq_ver

. ${prefix}/update_uniprot.sh $uniprot_ver $refseq_ver
. ${prefix}/update_facet.sh $uniprot_ver $refseq_ver
. ${prefix}/update_edgestore.sh

. ${prefix}/update_text_search.sh  $uniprot_ver $refseq_ver

script_dir="$(cd "$(dirname "$0")" && pwd)"
ruby ${script_dir}/../checker/check.rb $uniprot_ver $refseq_ver "finish"

ruby /data/store/rdf/togogenome/bin/check_update.rb $1

rake uniprot:taxon2ttl

echo "End Update All"
