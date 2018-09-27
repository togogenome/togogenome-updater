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

# When there was no update the refseq data(refseq_ver has not been specified), will just load from current data.
if [ -n "$refseq_ver" ]; then
  echo "Update and load new refseq version"
  . ${prefix}/update_refseq.sh $refseq_ver
  echo "Update fast & jbrowse new refseq version"
  . ${prefix}/update_fasta_jbrowse.sh $refseq_ver &
else
  echo "Load existing refseq version"
  genome_ver=`readlink -f /data/store/rdf/togogenome/genomes/current | awk -F'/' '{print $NF}'`
  refseq_ver=`readlink -f /data/store/rdf/togogenome/refseq/current | awk -F'/' '{print $NF}' | sed -e s/release//`
  . ${prefix}/load_refseq.sh $genomes_ver $refseq_ver &
fi

wait;

rake uniprot:taxon2ttl &

. ${prefix}/update_uniprot.sh $uniprot_ver
. ${prefix}/update_facet.sh
. ${prefix}/update_edgestore.sh

. ${prefix}/update_text_search.sh

echo "End Update All"
