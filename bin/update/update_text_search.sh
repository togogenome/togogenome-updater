#!/bin/sh
set -eu
script_dir="$(cd "$(dirname "$0")" && pwd)"

### Create the text search index and load to solr
echo "Start: Update text search index"
rake text_search:update $1
ruby ${script_dir}/../checker/check.rb $1 $2 "text_search:update"
echo "End: Update text search index"
