#!/bin/sh

### Fetch and create and load Assembly reports
echo "Start: Fetch Assembly reports"
rake genomes:fetch
echo "End: Update Assembly reports"