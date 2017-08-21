#!/bin/sh

### Create the text search index and load to solr
echo "Start: Update text search index"
rake text_search:update $1
echo "End: Update text search index"
