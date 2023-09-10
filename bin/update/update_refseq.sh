#!/bin/sh
set -eu

script_dir="$(cd "$(dirname "$0")" && pwd)"
### Fetch and create and load Assembly reports
echo "Start: Update Assembly reports"
rake genomes:fetch
rake genomes:prepare
ruby ${script_dir}/../checker/check.rb $1 $2 "genomes:prepare"
rake genomes:load
ruby ${script_dir}/../checker/check.rb $1 $2 "genomes:load"
echo "End: Update Assembly reports"

### Fetch and create and load RefSeq
echo "Start: Update Refseq"
rake refseq:fetch release$2
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:fetch"
rake refseq:refseq2ttl
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:refseq2ttl"
rake refseq:load_refseq $2
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:load_refseq"
## stats
rake refseq:refseq2stats
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:refseq2stats"
rake refseq:load_stats $2
ruby ${script_dir}/../checker/check.rb $1 $2 "refseq:load_stats"
echo "End: Update Refseq"
