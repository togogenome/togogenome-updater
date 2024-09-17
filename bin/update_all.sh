#!/bin/sh

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
. ${prefix}/fetch_uniprot.sh $uniprot_ver &

. ${prefix}/fetch_genomes.sh $refseq_ver
wait;

. ${prefix}/update_refseq.sh $refseq_ver



. ${prefix}/update_fasta_jbrowse.sh $refseq_ver


. ${prefix}/update_uniprot.sh $uniprot_ver
. ${prefix}/update_facet.sh
. ${prefix}/update_edgestore.sh

. ${prefix}/update_text_search.sh

ruby /data/store/rdf/togogenome/bin/check_update.rb $1

rake uniprot:taxon2ttl

echo "End Update All"
