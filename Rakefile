###
### TogoGenome update procedures
###

RDF_DIR = "/data/store/rdf"
GRAPH_NS = "http://togogenome.org"

HTTP_GET = "lftpget"

###
### Triple store
###

ISQL = "/data/store/virtuoso7.1/bin/isql 20711 dba dba"
ENDPOINT = "http://ep.dbcls.jp/sparql-import"

USAGE = <<"USAGE"

* Update Genomes

rake genomes:fetch            # Retrieve genomes/current/GENOME_REPORTS
rake genomes:prepare          # Prepare Assembly report RDF for TogoGenome 
rake genomes:load             # Load Assembly report to TogoGenome

* Update RefSeq

rake refseq:fetch release62    # Retrieve RefSeq entries to refseq/current
rake refseq:refseq2ttl         # Prepare RefSeq RDF for TogoGenome
rake refseq:refseq2fasta       # Generate fasta file of RefSeq for TogoGenome
rake refseq:refseq2jbrowse     # Generate jbrowse files of RefSeq for TogoGenome
rake refseq:refseq2stats       # Generate RefSeq stats RDF for TogoGenome
rake refseq:load 62            # Load Refseq to TogoGenome
rake refseq:load_stats 62      # Load Refseq stats to TogoGenome

* Update UniProt

rake uniprot:fetch 2013_11     # Retrieve UniProt RDF in ../uniprot/current
rake uniprot:unzip             # Unzip the donloaded UniProt RDF in ../uniprot/current/uniprot_unzip
rake uniprot:rdf2taxon         # Split UniProt RDF into taxon files in ../uniprot/current/uniprot_taxon.rdf
rake uniprot:taxon2ttl         # Convert UniProt taxon RDF to Turtle in ../uniprot/current/uniprot_taxon.ttl
rake uniprot:refseq2up         # Link TogoGenome and UniProt by /protein_id extracted from RefSeq"
rake uniprot:load_tgup         # Load TogoGenome to UniProt mapping RDF to TogoGenome
rake uniprot:copy              # Copy UniProt subset(mapped to RefSeq) for TogoGenome
rake uniprot:load 2013_11      # Load UniProt to TogoGenome
rake uniprot:uniprot2stats     # Generate UniProt stats RDF for TogoGenome
rake uniprot:load_stats        # Load UniProt stats to TogoGenome

* Update ontologies

(prefix ontology: for each task)

* Update FALDO ontology
rake ontology:faldo:fetch               # Retrieve FALDO
rake ontology:faldo:load 20130530       # Load FALDO to TogoGenome

* Update INSDC ontology
rake ontology:insdc:fetch               # Retrieve INSDC
rake ontology:insdc:load 20130530       # Load INSDC to TogoGenome

* Update Taxonomy ontology
rake ontology:taxonomy:fetch            # Retrieve NCBI taxdump files
rake ontology:taxonomy:load 20130826    # Load Taxonomy ontology to TogoGenome

* Update OBO ontologies
rake ontology:obo_go:fetch              # Retrieve Gene Ontology
rake ontology:obo_so:fetch              # Retrieve Sequence Ontology
rake ontology:obo_go:load 20130615      # Load Gene Ontology to TogoGenome
rake ontology:obo_so:load 20110512      # Load Sequence Ontology to TogoGenome

* Update MEO/MPO/GMO/MCCV/PDO/GAZETTEER and LOD (GOLD/BRC)
rake ontology:meo:load 0.6              # Load MEO to TogoGenome
rake ontology:mpo:load 0.3              # Load MPO to TogoGenome
rake ontology:gmo:load 0.1b             # Load GMO to TogoGenome
rake ontology:mccv:load 0.92            # Load MCCV to TogoGenome
rake ontology:pdo:load 0.11             # Load PDO to TogoGenome
rake ontology:pdo:load_lod 20130902     # Load PDO_MAPPING to TogoGenome
rake ontology:csso:load 0.2             # Load CSSO to TogoGenome
rake ontology:gazetteer:load 20130906   # Load GAZETTEER to TogoGenome
rake ontology:brc:load 20130925         # Load BRC to TogoGenome
rake ontology:nbrc:load 20200229        # Load NBRC to TogoGenome
rake ontology:jcm:load 20200229         # Load JCM to TogoGenome
rake ontology:gold:load 20130827        # Load GOLD to TogoGenome

* Update EdgeStore

rake edgestore:check           # Check update status
rake edgestore:fetch           # Retrieve EdgeStore data
rake edgestore:load 20131021   # Load EdgeStore to TogoGenome

* linkage(facet serach data)

rake linkage:prepare           # Generate linkage data for facet search performance
rake linkage:load              # Load linkage RDF to TogoGenome

* Update text search

rake text_search update        # Generate text search index(for Solr4) files

* Graphs

rake graph:list                # Show current graphs
rake graph:stat                # Show graph statistics
rake graph:drop name           # Delete graph <GRAPH_NS/graph/name>
rake graph:watch               # Show number of remaining files for loading

USAGE

###
### Methods
###

def set_name
  if ARGV.size > 1
    name = ARGV.last
    task name.to_sym  # do nothing, just to avoid "Don't know how to build task #{name}"
  else
    date = Time.now.strftime("%Y%m%d")
  end
  return name || date
end

def create_subdir(path, name)
  sh "mkdir -p #{path}/#{name}"
  return "#{path}/#{name}"
end

def link_current(path, name)
  sh "cd #{path}; ln -snf #{name} current"
end

def isql_create(graph, name)
  sleep 1
  time = Time.now.strftime("%Y%m%d-%H%M%S")
  path = "isql/#{time}-#{graph}-#{name}.isql"
  return path
end

def isql_write(file, line)
  file.puts "ECHOLN \"#{line}\";"
  file.puts line
end

def sh_create(graph, name)
  sleep 1
  time = Time.now.strftime("%Y%m%d-%H%M%S")
  path = "isql/#{time}-#{graph}-#{name}.sh"
  return path
end

def load_rdf(path, graph, name)
  isql = isql_create(graph, name)
  File.open(isql, "w") do |file|
    isql_write(file, "log_enable(2, 1);")
    isql_write(file, "DB.DBA.RDF_LOAD_RDFXML_MT(file_to_string_output('#{path}'), '', '#{GRAPH_NS}/graph/#{graph}');")
    isql_write(file, "checkpoint;")
  end
  sh "#{ISQL} #{isql}"
end

def load_ttl(path, graph, name)
  isql = isql_create(graph.sub('/',''), name)
  File.open(isql, "w") do |file|
    isql_write(file, "log_enable(2, 1);")
    #   1 - Single quoted and double quoted strings may with newlines.
    #   2 - Allows bnode predicates (but SPARQL processor may ignore them!).
    #   4 - Allows variables, but triples with variables are ignored.
    #   8 - Allows literal subjects, but triples with them are ignored.
    #  16 - Allows '/', '#', '%' and '+' in local part of QName ("Qname with path")
    #  32 - Allows invalid symbols between '<' and '>', i.e. in relative IRIs.
    #  64 - Relax TURTLE syntax to include popular violations.
    # 128 - Try to recover from lexical errors as much as it is possible.
    # 256 - Allows TriG syntax, thus loading data in more than one graph.
    # 512 - Allows loading N-quad dataset files with and optional context value to indicate provenance as detailed http://sw.deri.org/2008/07/n-quads
    # 81 = 64 + 16 + 1
    isql_write(file, "DB.DBA.TTLP_MT(file_to_string_output('#{path}'), '', '#{GRAPH_NS}/graph/#{graph}', 81);")
    isql_write(file, "checkpoint;")
  end
  sh "#{ISQL} #{isql}"
end

def load_dir(path, pattern, graph, name)
  isql = isql_create(graph.sub('/',''), name)
  File.open(isql, "w") do |file|
    isql_write(file, "log_enable(2, 1);")
    isql_write(file, "ld_dir_all('#{path}', '#{pattern}', '#{GRAPH_NS}/graph/#{graph}');")
    isql_write(file, "rdf_loader_run();")
    isql_write(file, "checkpoint;")
  end
  sh "#{ISQL} #{isql}"
end

def load_dir_multiple(path, pattern, graph, name, thread_num)
  sh_file = sh_create(graph.sub('/',''), name)
  File.open(sh_file, "w") do |file|
    file.puts "#!/bin/sh"
    file.puts ""
    file.puts "#{ISQL} exec=\"ld_dir_all('#{path}', '#{pattern}', '#{GRAPH_NS}/graph/#{graph}');\""
    for num in 1..thread_num do
      file.puts "#{ISQL} exec=\"rdf_loader_run();\" &"
    end
    file.puts "#{ISQL} exec=\"checkpoint;\""
    file.puts "wait"
  end
  File.chmod(0755,sh_file)
  sh "#{RDF_DIR}/togogenome/#{sh_file}"
end

def update_graph(graph, name)
  sparql = "sparql 
    PREFIX dct: <http://purl.org/dc/terms/>
    DELETE FROM <#{GRAPH_NS}/graph> {
      <#{GRAPH_NS}/graph/#{graph}> ?p ?o .
    }
    WHERE {
      GRAPH <#{GRAPH_NS}/graph> {
        <#{GRAPH_NS}/graph/#{graph}> ?p ?o .
      }
    }
    INSERT DATA INTO <#{GRAPH_NS}/graph> {
      <#{GRAPH_NS}/graph/#{graph}> dct:isVersionOf <#{GRAPH_NS}/graph/#{graph}/#{name}> .
    }
  ;"
  isql = isql_create(graph, name)
  File.open(isql, "w") do |file|
    isql_write(file, sparql)
  end
  sh "#{ISQL} #{isql}"
end

###
### Tasks
###

task :default => :usage

task :usage do
  puts USAGE
end

###
### Graph
###

namespace :graph do

  desc "Show current graphs"
  task :list do
    sh "SPARQL_ENDPOINT='#{ENDPOINT}' sparql.rb query 'select * where { graph <#{GRAPH_NS}/graph> {?s ?p ?o} } order by ?s'"
  end
  
  desc "Show graph statistics"
  task :stat do
    sparql = "sparql
      select (?g as ?graph_name) (?v as ?graph_version) (?c as ?triples)
      where {
        graph <#{GRAPH_NS}/graph> {
          ?g ?p ?v
        }
        {
          select ?g (count(*) as ?c)
          where {
            graph ?g {?s1 ?p1 ?o1}
          } group by ?g
        }
      } order by ?g
    ;"
    isql = isql_create('stat', 'graph')
    File.open(isql, "w") do |file|
      isql_write(file, sparql)
    end
    sh "#{ISQL} #{isql}"
  end
  
  desc "Drop graph"
  task :drop do
    name = set_name
    isql = isql_create('drop', name)
    File.open(isql, "w") do |file|
      isql_write(file, "log_enable(2, 1);")
      isql_write(file, "sparql clear graph <#{GRAPH_NS}/graph/#{name}>;")
      #[TODO] delete graph infomation from graph's graph
      isql_write(file, "DELETE FROM DB.DBA.LOAD_LIST where ll_graph = '#{GRAPH_NS}/graph/#{name}';") #delete load history for reload
    end
    sh "#{ISQL} #{isql}"
  end
  
  desc "Show number of remaining files for loading"
  task :watch do
    sh "echo 'select count(*) from DB.DBA.LOAD_LIST where ll_state = 0;' | #{ISQL}"
  end
end

###
### Ontologies
###

namespace :ontology do

#
# FALDO
#

namespace :faldo do
  desc "Retrieve FALDO"
  task :fetch do
    name = set_name
    path = create_subdir('ontology/faldo', name)
    sh "cd #{path}; wget http://biohackathon.org/resource/faldo.ttl -O faldo.ttl"
    link_current('ontology/faldo', name)
  end
  
  desc "Load FALDO to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/faldo/current/faldo.ttl", 'faldo', name)
    update_graph('faldo', name)
  end
end

#
# INSDC
#

namespace :insdc do
  desc "Retrieve INSDC"
  task :fetch do
    name = set_name
    path = create_subdir('ontology/insdc', name)
    sh "cd #{path}; wget http://ddbj.nig.ac.jp/ontologies/nucleotide.ttl -O nucleotide.ttl"
    link_current('ontology/insdc', name)
  end
  
  desc "Load INSDC to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/insdc/current/nucleotide.ttl", 'insdc', name)
    update_graph('insdc', name)
  end
end

#
# Taxonomy (NCBI taxdump)
#

namespace :taxonomy do
  desc "Retrieve DDBJ taxonomy"
  task :fetch do
    name = set_name
    path = create_subdir('ontology/taxonomy', name)
    sh "cd #{path}; wget http://ddbj.nig.ac.jp/ontologies/taxonomy.ttl -O taxonomy.ttl"
    link_current('ontology/taxonomy', name)
  end
  
  desc "Load Taxonomy (DDBJ) to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/taxonomy/current/taxonomy.ttl", 'taxonomy', name)
    #load_ttl("#{RDF_DIR}/togogenome/ontology/taxonomy/current/taxcite.ttl", 'taxonomy', name)
    update_graph('taxonomy', name)
  end
end

#
# GO
#

namespace :obo_go do
  desc "Retrieve Gene Ontology"
  task :fetch do
    name = set_name
    path = create_subdir('ontology/go', name)
    sh "cd #{path}; #{HTTP_GET} http://purl.obolibrary.org/obo/go.owl"
    link_current('ontology/go', name)
  end
  
  desc "Load Gene Ontology to TogoGenome"
  task :load do
    name = set_name
    load_rdf("#{RDF_DIR}/togogenome/ontology/go/current/go.owl", 'go', name)
    update_graph('go', name)
  end
end

#
# SO
#

namespace :obo_so do
  desc "Retrieve Sequence Ontology"
  task :fetch do
    name = set_name
    path = create_subdir('ontology/so', name)
    sh "cd #{path}; #{HTTP_GET} http://purl.obolibrary.org/obo/so.owl"
    link_current('ontology/so', name)
  end
  
  desc "Load Sequence Ontology to TogoGenome"
  task :load do
    name = set_name
    load_rdf("#{RDF_DIR}/togogenome/ontology/so/current/so.owl", 'so', name)
    update_graph('so', name)
  end
end

#
# MEO
#

namespace :meo do
 desc "Load MEO to TogoGenome"
 task :load do
   name = set_name
   load_rdf("#{RDF_DIR}/togogenome/ontology/MEO/current/meo.owl", 'meo', name)
   update_graph('meo', name)
 end
end

#
# MEO(0.9)
#

namespace :meo_dag do
  desc "Load MEO0.9 to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/MEO_0.9/current/meo.ttl", 'meo0.9', name)
    update_graph('meo0.9', name)
  end
end

#
# MPO
#

namespace :mpo do
  desc "Load MPO to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/MPO/current/mpo.ttl", 'mpo', name)
    update_graph('mpo', name)
  end
end

#
# MCCV
#

namespace :mccv do
  desc "Load MCCV to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/MCCV/current/mccv.ttl", 'mccv', name)
    update_graph('mccv', name)
  end
end

#
# PDO
#

namespace :pdo do
  desc "Load PDO to TogoGenome"
  task :load do
    name = set_name
    load_rdf("#{RDF_DIR}/togogenome/ontology/PDO/current/pdo.owl", 'pdo', name)
    update_graph('pdo', name)
  end

  desc "Load PDO_MAPPING to TogoGenome (rename to pdo_lod ?)"
  task :load_lod do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/PDO/current/mapping.ttl", 'pdo_mapping', name)
    update_graph('pdo_mapping', name)
  end
end

#
# CSSO
#

namespace :csso do
  desc "Load CSSO to TogoGenome (move to ontology/CSSO ?)"
  task :load do
    name = set_name
    load_rdf("#{RDF_DIR}/togogenome/ontology/PDO/current/csso.owl", 'csso', name)
    update_graph('csso', name)
  end
end

#
# GAZETTEER
#

namespace :gazetteer do
  desc "Load GAZETTEER to TogoGenome"
  task :load do
    name = set_name
    load_rdf("#{RDF_DIR}/togogenome/ontology/GAZETTEER/current/gazetteer.owl", 'gazetteer', name)
    load_ttl("#{RDF_DIR}/togogenome/ontology/GAZETTEER/current/gazetteer_lonlat.ttl", 'gazetteer', name)
    update_graph('gazetteer', name)
  end
end

#
# BRC
#

namespace :brc do
  desc "Load BRC to TogoGenome"
  task :load do
    name = set_name
    load_dir("#{RDF_DIR}/togogenome/ontology/BRC/current", '*.ttl', 'brc', name)
    update_graph('brc', name)
  end
end

#
# NBRC
#

namespace :nbrc do
  desc "Load NBRC to TogoGenome"
  task :load do
    name = set_name
    load_dir("#{RDF_DIR}/togogenome/ontology/nbrc/current", '*.ttl', 'nbrc', name)
    update_graph('nbrc', name)
  end
end

#
# JCM
#

namespace :jcm do
  desc "Load JCM to TogoGenome"
  task :load do
    name = set_name
    load_dir("#{RDF_DIR}/togogenome/ontology/jcm/current", '*.ttl', 'jcm', name)
    update_graph('jcm', name)
  end
end

#
# GOLD
#

namespace :gold do
  desc "Load GOLD to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/GOLD/current/gold2meo.ttl", 'gold', name)
    load_ttl("#{RDF_DIR}/togogenome/ontology/GOLD/current/gold2mpo.ttl", 'gold', name)
    load_ttl("#{RDF_DIR}/togogenome/ontology/GOLD/current/gold2taxon.ttl", 'gold', name)
    load_dir("#{RDF_DIR}/togogenome/ontology/GOLD/current/additional", '*.ttl', 'gold', name)
    update_graph('gold', name)
  end
end

#
# GMO
#

namespace :gmo do
  desc "Load GMO to TogoGenome"
  task :load do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/GMO/current/gmo.ttl", 'gmo', name)
    update_graph('gmo', name)
  end
end

end  # :ontology

###
### Genomes
###

namespace :genomes do
  desc "Rsync with NCBI sites 'genomes/ASSEMBLY_REPORTS' and 'genomes/all"
  task :fetch do
    name = set_name
    path = create_subdir('genomes', name)
    link_current('genomes', name)
    sh "perl #{RDF_DIR}/togogenome/bin/linksets/ftp/assembly_reports_rsync.pl /data/store/rdf/togogenome/genomes"
  end

  desc "Convert ASSEBLY_REPORTS to Turtle"
  task :prepare do
    sh "cd #{RDF_DIR}/togogenome/bin/rdfsummit/; #{RDF_DIR}/togogenome/bin/rdfsummit/insdc2ttl/assembly_reports2ttl.rb #{RDF_DIR}/togogenome/genomes/data #{RDF_DIR}/togogenome/genomes/current"
  end

  desc "Load Assembly report Turtle to TogoGenome"
  task :load do
    name = set_name
    # load only refseq(GCF) data. skip genbank(GCA) data
    load_ttl("#{RDF_DIR}/togogenome/genomes/current/genomes/ASSEMBLY_REPORTS/assembly_summary_refseq.ttl", 'assembly_report', name)
    load_dir_multiple("#{RDF_DIR}/togogenome/genomes/current/genomes/all/GCF", '*.ttl', 'assembly_report', name, 6)
    update_graph('assembly_report', name)
  end
end

###
### RefSeq
###

namespace :refseq do
  REFSEQ_WORK_DIR = "#{RDF_DIR}/togogenome/refseq/current" 

  desc "Retrieve RefSeq entries to refseq/current"
  task :fetch do
    name = set_name
    create_subdir("refseq", name)
    link_current("refseq", name)
    sh "bin/refseq_list.rb #{ENDPOINT} > #{REFSEQ_WORK_DIR}/refseq_list.json"
    sh "bin/wget_refseq.rb #{REFSEQ_WORK_DIR}/refseq_list.json #{REFSEQ_WORK_DIR}/refseq.gb true >> #{REFSEQ_WORK_DIR}/refseq_wget.log"
    #delete error data
    sh "perl -pi -e 's/; GO//g' #{REFSEQ_WORK_DIR}/refseq.gb/1883368/PRJNA353681/NC_031927.1"
  end
  
  desc "Convert RefSeq to Turtle"
  task :refseq2ttl do
    sh "bin/refseq2ttl_all.rb #{REFSEQ_WORK_DIR}/refseq_list.json 2> #{REFSEQ_WORK_DIR}/refseq2ttl.log"
  end
  
  desc "Convert RefSeq to FASTA"
  task :refseq2fasta do
    sh "bin/refseq2fasta.rb > #{REFSEQ_WORK_DIR}/refseq.fasta"
  end
  
  desc "Prepare JBrowse conf files"
  task :refseq2jbrowse do
    sh "cp -pr refseq/jbrowse_blank refseq/current/jbrowse_upd"
    sh "bin/refseq2jbrowse.rb refseq/current/refseq.fasta"
    sh "if [ -f refseq/current/jbrowse ]; then mv refseq/current/jbrowse refseq/current/jbrowse_old; fi"
    sh "mv refseq/current/jbrowse_upd refseq/current/jbrowse"
    sh "rm -rf refseq/current/jbrowse_old"
  end

  desc "Generate RefSeq stats turtle"
  task :refseq2stats do
    sh "bin/refseq_stats.rb #{ENDPOINT} #{REFSEQ_WORK_DIR}/refseq_list.json #{REFSEQ_WORK_DIR}/refseq.stats.ttl"
    sh "bin/refseq_stats_gc.rb #{REFSEQ_WORK_DIR}/refseq_list.json #{REFSEQ_WORK_DIR}/refseq.stats.gc.ttl"
    sh "bin/refseq_assembly_link.rb #{REFSEQ_WORK_DIR}/refseq_list.json > #{REFSEQ_WORK_DIR}/refseq.stats.assembly.ttl"
  end
  
  desc "Load Refseq to TogoGenome"
  task :load_refseq do
    name = set_name
    load_dir_multiple("#{REFSEQ_WORK_DIR}/refseq.ttl", '*.ttl', 'refseq', name, 4)
    update_graph('refseq', name)
  end

  desc "Load RefSeq statistics to TogoGenome"
  task :load_stats do
    name = set_name
    load_ttl("#{REFSEQ_WORK_DIR}/refseq.stats.ttl", 'stats', name)
    load_ttl("#{REFSEQ_WORK_DIR}/refseq.stats.gc.ttl", 'stats', name)
    load_ttl("#{REFSEQ_WORK_DIR}/refseq.stats.assembly.ttl", 'stats', name)
    update_graph('stats', name)
  end

end

###
### UniProt
###

namespace :uniprot do

  desc "Retrieve UniProt RDF in ../uniprot/current"
  task :fetch do
    name = set_name
    path = create_subdir("#{RDF_DIR}/uniprot", name)
    sh "cd #{path}; #{HTTP_GET} ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release/knowledgebase/idmapping/idmapping.dat.gz"
    sh "cd #{path}; echo 'mirror -X uniparc_* -X uniprotkb_* -X uniref_* rdf' | lftp ftp://ftp.ebi.ac.uk/pub/databases/uniprot/current_release"
    link_current("#{RDF_DIR}/uniprot", name)
    create_subdir('uniprot', name)
    link_current('uniprot', name)
  end

  task :unzip do
    path = "#{RDF_DIR}/uniprot/current"
    sh "mkdir -p #{path}/uniprot_unzip"
    sh "cp -p #{path}/rdf/core.owl #{path}/uniprot_unzip"
    sh "cp -p #{path}/rdf/*.owl.xz #{path}/uniprot_unzip"
    sh "cp -p #{path}/rdf/[a-t]*.rdf.xz #{path}/uniprot_unzip"
    sh "cp -p #{path}/idmapping.dat.gz #{path}/uniprot_unzip"
    sh "gunzip #{path}/uniprot_unzip/*.gz"
    sh "xz -dv #{path}/uniprot_unzip/*.xz"
  end

  desc "Split UniProt RDF into taxon files"
  task :rdf2taxon do
    sh "#{RDF_DIR}/uniprot/bin/uniprot_taxon.rb #{RDF_DIR}/uniprot/current/uniprot_unzip/uniprotkb #{RDF_DIR}/uniprot/current/uniprot_taxon.rdf &>> #{RDF_DIR}/uniprot/current/rdf2taxon.log"
  end

  task :remove_unzip do
    sh "rm -rf #{RDF_DIR}/uniprot/current/uniprot_unzip/uniprotkb"
  end

  desc "Convert UniProt taxon RDF to Turtle"
  task :taxon2ttl do
    path = "#{RDF_DIR}/togogenome/uniprot/current"
    sh "#{RDF_DIR}/togogenome/bin/uniprot_rdf2ttl.rb #{path}/refseq #{path}/refseq_ttl &>> #{path}/rapper_ttl.log"
  end

  desc "Link TogoGenome and UniProt by /protein_id extracted from RefSeq"
  task :refseq2up do
    # Generate refseq.up.ttl
    path = "#{RDF_DIR}/togogenome/uniprot/current"
    sh "grep 'RefSeq\\|NCBI_TaxID\\|GeneID' #{RDF_DIR}/uniprot/current/uniprot_unzip/idmapping.dat | grep -v 'RefSeq_NT' > #{path}/filterd_idmapping.dat"
    sh "bin/refseq2up.rb #{ENDPOINT} #{REFSEQ_WORK_DIR}/refseq_list.json #{path}/refseq.up.ttl #{path}/filterd_idmapping.dat 2> #{path}/refseq.up.log"
  end

  desc "Load TogoGenome to UniProt mappings"
  task :load_tgup do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/uniprot/current/refseq.up.ttl", 'tgup', name)
    update_graph('tgup', name)
  end

  desc "Download UniProt rdf (by tax_ids) for TogoGenome"
  task :download_rdf do
    sh "bin/get_uniprot_rdf.rb #{RDF_DIR}/togogenome/uniprot/current/refseq.tax.json  #{RDF_DIR}/togogenome/uniprot/current/refseq"
  end

  desc "Copy UniProt subset(mapped to RefSeq) for TogoGenome"
  task :copy do
    sh "bin/copy_uniprot_refseq.rb #{RDF_DIR}/togogenome/uniprot/current/refseq.tax.json #{RDF_DIR}/uniprot/current/uniprot_taxon.rdf  #{RDF_DIR}/togogenome/uniprot/current/refseq"
  end

  desc "Load UniProt to TogoGenome"
  task :load do
    name = set_name
    load_dir("#{RDF_DIR}/uniprot/current/uniprot_unzip", '*.owl', 'uniprot', name)
    load_dir("#{RDF_DIR}/uniprot/current/uniprot_unzip", '*.rdf', 'uniprot', name)
    load_dir_multiple("#{RDF_DIR}/togogenome/uniprot/current/refseq", '*.rdf.gz', 'uniprot', name, 6)
    update_graph('uniprot', name)
  end

  desc "Generate UniProt stats turtle"
  task :uniprot2stats do
    sh "bin/uniprot_pfam_stats.rb \"#{ISQL}\" #{RDF_DIR}/togogenome/uniprot/current/pfam_stats"
  end

  desc "Load RefSeq statistics to TogoGenome"
  task :load_stats do
    name = set_name
    load_dir("#{RDF_DIR}/togogenome/uniprot/current/pfam_stats", '*.ttl', 'stats', name)
  end

end

###
### EdgeStore
###

namespace :edgestore do
  desc "Check EdgeStore data"
  task :check do
    sh "ssh w3sw@gw.ddbj.nig.ac.jp tail /home/w3sw/rdf/log/edgestore.log"
  end

  desc "Retrieve EdgeStore data"
  task :fetch do
    name = set_name
    path = create_subdir("#{RDF_DIR}/edgestore", name)
    sh "scp -pr w3sw@gw.ddbj.nig.ac.jp:/home/w3sw/rdf/log/edgestore.log #{RDF_DIR}/edgestore/"
    sh "scp -pr w3sw@gw.ddbj.nig.ac.jp:/home/w3sw/rdf/edgestore/\*.ttl #{path}"
    sh "rm -f #{path}/togogenome2uniprot.ttl"
    link_current("#{RDF_DIR}/edgestore", name)
  end

  desc "Load EdgeStore to TogoGenome"
  task :load do
    name = set_name
    load_dir("#{RDF_DIR}/edgestore/current", '*.ttl', 'edgestore', name)
    update_graph('edgestore', name)
  end
end

###
### linkage
###

namespace :linkage do
  desc "Generate linkage data for search performance"
  task :prepare => [:meo_descendants, :mpo_descendants, :goup, :gotax, :tgtax, :taxonomy_lite]

  desc "Prepare RDF for tracking directly the descendants of each MEO object"
  task :meo_descendants do
    sh "bin/sparql_construct.rb #{ENDPOINT} bin/sparql/meo_descendants.rq > #{RDF_DIR}/togogenome/ontology/MEO/current/meo_descendants.ttl"
  end

  desc "Prepare RDF for tracking directly the descendants of each MPO object"
  task :mpo_descendants do
    sh "bin/sparql_construct.rb #{ENDPOINT} bin/sparql/mpo_descendants.rq > #{RDF_DIR}/togogenome/ontology/MPO/current/mpo_descendants.ttl"
  end
  desc "Prepare RDF for linking directly between the gene_ontology and uniprot entries"
  task :goup do
    sh "bin/go_up2ttl.rb #{ENDPOINT} \"#{ISQL}\" #{RDF_DIR}/togogenome/uniprot/current/goup"
  end
  desc "Prepare RDF for linking directly between the gene_ontology and taxonomy"
  task :gotax do
    sh "bin/go_tax2ttl.rb #{ENDPOINT} \"#{ISQL}\" #{RDF_DIR}/togogenome/uniprot/current/gotax"
  end
  desc "Prepare RDF of TogoGenome taxonomy to parent taxonomy mappings"
  task :tgtax do
    sh "bin/sparql_construct.rb #{ENDPOINT} bin/sparql/tgtax_refseq.rq > #{REFSEQ_WORK_DIR}/refseq.tgtax.ttl"
    sh "bin/sparql_construct.rb #{ENDPOINT} bin/sparql/tgtax_environment.rq > #{REFSEQ_WORK_DIR}/environment.tgtax.ttl"
    sh "bin/sparql_construct.rb #{ENDPOINT} bin/sparql/tgtax_phenotype.rq > #{REFSEQ_WORK_DIR}/phenotype.tgtax.ttl"
  end
  desc "Prepare RDF of in-use taxonomy tree"
  task :taxonomy_lite do
    sh "bin/sparql_construct.rb #{ENDPOINT} bin/sparql/taxonomy_lite.rq > #{REFSEQ_WORK_DIR}/taxonomy_lite.ttl"
  end

  desc "Load linkage RDF to TogoGenome"
  task :load => [:load_meo_descendants, :load_mpo_descendants, :load_goup, :load_gotax, :load_tgtax, :load_taxonomy_lite]

  desc "Load MEO descendants to TogoGenome"
  task :load_meo_descendants do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/MEO/current/meo_descendants.ttl", 'meo_descendants', name)
    update_graph('meo_descendants', name)
  end

  desc "Load MPO descendants to TogoGenome"
  task :load_mpo_descendants do
    name = set_name
    load_ttl("#{RDF_DIR}/togogenome/ontology/MPO/current/mpo_descendants.ttl", 'mpo_descendants', name)
    update_graph('mpo_descendants', name)
  end

  desc "Load linkage between gene ontology and uniprot RDF to TogoGenome"
  task :load_goup do
    name = set_name
    load_dir("#{RDF_DIR}/togogenome/uniprot/current/goup", '*.ttl', 'goup', name)
    update_graph('goup', name)
  end

  desc "Load linkage between gene ontology and taxonomy RDF to TogoGenome"
  task :load_gotax do
    name = set_name
    load_dir("#{RDF_DIR}/togogenome/uniprot/current/gotax", '*.ttl', 'gotax', name)
    update_graph('gotax', name)
  end

  desc "Load in-use taxonomy to parent taxonomy mappings"
  task :load_tgtax do
    name = set_name
    load_ttl("#{REFSEQ_WORK_DIR}/refseq.tgtax.ttl", 'tgtax', name)
    load_ttl("#{REFSEQ_WORK_DIR}/environment.tgtax.ttl", 'tgtax', name)
    load_ttl("#{REFSEQ_WORK_DIR}/phenotype.tgtax.ttl", 'tgtax', name)
    update_graph('tgtax', name)
  end

  desc "Load in-use taxonomy tree"
  task :load_taxonomy_lite do
    name = set_name
    load_ttl("#{REFSEQ_WORK_DIR}/taxonomy_lite.ttl", 'taxonomy_lite', name)
    update_graph('taxonomy_lite', name)
  end
end

###
### Update text search
###

namespace :text_search do
  desc "Update data for text search"
  task :update do
    name = set_name
    path = create_subdir('text_search', name)
    link_current("text_search", name)
    sh "bin/text_search/update_text_index.sh"
  end
end
