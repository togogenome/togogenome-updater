#!/bin/sh

### Create and load tgup(TogoGenome + UniProt)
echo "Start: Update tgup"
rake uniprot:refseq2up
rake uniprot:load_tgup
echo "End: Update tgup"

### Convert (RDF/XML=>Turtle) and load UniProt
echo "Start: Update UniProt"
rake uniprot:download_rdf
rake uniprot:load $1
rake uniprot:uniprot2stats
rake uniprot:load_stats
echo "End: Update UniProt"
