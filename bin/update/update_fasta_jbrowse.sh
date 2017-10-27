#!/bin/sh

### Generate RefSeq fasta file
echo "Start: Generate fasta"
rake refseq:refseq2fasta $1
echo "End: Generate fasta"

### Generate RefSeq jbrowse file
echo "Start: Generate jbrowse"
rake refseq:refseq2jbrowse
echo "End: Generate jbrowse"
