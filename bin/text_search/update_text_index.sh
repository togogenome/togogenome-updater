#!/bin/sh

db_file="/data/store/virtuoso7.1/var/lib/virtuoso/db/virtuoso.db"
no_text_db_file="/data/store/virtuoso7.1/var/lib/virtuoso/virtuoso.db.no_text"
with_text_db_file="/data/store/virtuoso7.1/var/lib/virtuoso/virtuoso.db.with_text"
serv="71"
bin_prefix="/data/store/bin"
text_bin_prefix="/data/store/rdf/togogenome/bin/text_search"

# evacuates orginal db file, since several raphs are added for creating the text index data.  
echo "evacuates orginal db file"
echo ">>> Stopping ${serv} ..."
${bin_prefix}/${serv}.sh stop
echo ""
sleep 60;
echo ">>> Copying db file ..."
cp ${db_file} ${no_text_db_file}
echo ">>> Starting ${serv} ..."
${bin_prefix}/${serv}.sh start
sleep 600;

#prepare
echo "prepare"
${text_bin_prefix}/prepare.rb

#create index data
echo "create index data"
${text_bin_prefix}/environment_text_idx.rb
${text_bin_prefix}/phenotype_text_idx.rb
${text_bin_prefix}/organism_text_idx.rb
${text_bin_prefix}/gene_text_idx.rb

#clear solr data and load a new index data
echo "load index data to solr"
${bin_prefix}/solr4_dev.sh stop
sleep 60;
${bin_prefix}/solr4_dev.sh clear 
${bin_prefix}/solr4_dev.sh start
sleep 300;
${text_bin_prefix}/load_solr.rb >> load_solr.log 2>>load_solr2.log

#gets back orginal db file 
echo "gets back orginal db file"
echo ">>> Stopping ${serv} ..."
${bin_prefix}/${serv}.sh stop
echo ""
sleep 60;
echo ">>> Copying db file ..."
mv ${db_file} ${with_text_db_file}
cp ${no_text_db_file} ${db_file}
echo ">>> Starting ${serv} ..."
${bin_prefix}/${serv}.sh start
