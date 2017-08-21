#!/bin/sh

### Load Assembly reports
echo "Start: Load Assembly reports"
rake genomes:load $1
echo "End: Load Assenbly reports"

### Load Refseq data
echo "Start: Load Refseq"
rake refseq:load_refseq $2
rake refseq:load_stats $2
echo "End: Load Refseq"
