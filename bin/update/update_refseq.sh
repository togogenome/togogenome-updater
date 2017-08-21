#!/bin/sh

### Fetch and create and load Assembly reports
echo "Start: Update Assembly reports"
rake genomes:fetch
rake genomes:prepare
rake genomes:load
echo "End: Update Assembly reports"

### Fetch and create and load RefSeq 
echo "Start: Update Refseq"
rake refseq:fetch release$1
rake refseq:refseq2ttl
rake refseq:load_refseq $1
rake refseq:refseq2stats
rake refseq:load_stats $1
echo "End: Update Refseq"
