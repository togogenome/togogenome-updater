./create_gene_text_idx.rb http://ep.dbcls.jp/sparql-import "/data/store/virtuoso7.1/bin/isql 20711 dba dba" >  test.txt

log_enable(3, 1);
DB.DBA.TTLP_MT(file_to_string_output('/data/store/rdf/togogenome/bin/text_search/gene_list.ttl'), '', 'http://togogenome.org/graph/temp_text_gene', 81);
checkpoint;
