#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
### Generate RefSeq fasta file
echo "Start: Generate fasta"
rake refseq:refseq2fasta $2
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:refseq2fasta"
echo "End: Generate fasta"

### Generate RefSeq jbrowse file
echo "Start: Generate jbrowse"
rake refseq:refseq2jbrowse
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:refseq2jbrowse"
echo "End: Generate jbrowse"
