#!/bin/sh

### Fetch UniProt idmapping.dat
echo "Start Fetch Uniprot idmapping.dat file"
rake uniprot:fetch_idmapping $1
echo "End Fetch Uniprot"

