#!/bin/sh

### Fetch UniProt data and create RDF/XML file
echo "Start Fetch Uniprot"
rake uniprot:fetch $1
rake uniprot:unzip
rake uniprot:rdf2taxon
echo "End Fetch Uniprot"

