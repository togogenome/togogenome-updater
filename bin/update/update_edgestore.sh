#!/bin/sh

### Fetch and load EdgeStore data
echo "Start: Update edgeStore"
rake edgestore:fetch
rake edgestore:load
echo "End: Update edgeStore"
