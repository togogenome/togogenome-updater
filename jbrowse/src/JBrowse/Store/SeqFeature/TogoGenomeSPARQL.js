define("JBrowse/Store/SeqFeature/TogoGenomeSPARQL", [ 'dojo/_base/declare',
         'dojo/_base/lang',
         'dojo/_base/array',
         'dojo/request/xhr',
         'JBrowse/Store/SeqFeature',
         'JBrowse/Store/DeferredStatsMixin',
         'JBrowse/Store/SeqFeature/GlobalStatsEstimationMixin',
         'JBrowse/Util',
         'JBrowse/Model/SimpleFeature',
         'dojo/io-query'
       ],
       function(
           declare,
           lang,
           array,
           xhr,
           SeqFeatureStore,
           DeferredStatsMixin,
           GlobalStatsEstimationMixin,
           Util,
           SimpleFeature,
           ioQuery
       ) {

return declare( [ SeqFeatureStore, DeferredStatsMixin, GlobalStatsEstimationMixin ],

/**
 * @lends JBrowse.Store.SeqFeature.TogoGenomeSPARQL
 */
{

    /**
     * JBrowse feature backend to retrieve features from a TogoGenome SPARQL endpoint.
     * @constructs
     */
    constructor: function(args) {
        this.url = this.urlTemplate;
        this.refSeq = args.refSeq;
        this.baseUrl = args.baseUrl;
        this.density = 0;
        this.url = Util.resolveUrl(
            this.baseUrl,
            Util.fillTemplate( args.urlTemplate,
                               { 'refseq': this.refSeq.name }
                             )
        );
        this.queryTemplate = args.queryTemplate;
        if( ! this.queryTemplate ) {
            console.error("No queryTemplate set for SPARQL backend, no data will be displayed");
        }

        var thisB = this;
        this._estimateGlobalStats()
            .then(
                function( stats ) {
                    thisB.globalStats = stats;
                    thisB._deferred.stats.resolve( stats );
                },
                lang.hitch( this, '_failAllDeferred' )
            );
    },

    // load: function() {
    //     // ping the endpoint to see if it's there
    //     dojo.xhrGet({ url: this.url+'?'+ioQuery.objectToQuery({ query: 'SELECT ?s WHERE { ?s ?p ?o } LIMIT 1' }),
    //                   handleAs: "text",
    //                   failOk: false,
    //                   load:  Util.debugHandler( this, function(o) { this.loadSuccess(o); }),
    //                   error: dojo.hitch( this, function(error) { this.loadFail(error, this.url); } )
    //     });
    // },

    _makeQuery: function( query ) {
        if( this.config.variables )
            query = dojo.mixin( dojo.mixin( {}, this.config.variables ),
                                query
                              );

        return Util.fillTemplate( this.queryTemplate, query );
    },

    _getFeatures: function() {
        this.getFeatures.apply( this, arguments );
    },

    getFeatures: function( query, featCallback, finishCallback, errorCallback ) {
        //console.log(query);
        if( this.queryTemplate ) {
            var thisB = this;
            xhr.get( this.url+'?'+ioQuery.objectToQuery({
                                                            query: this._makeQuery( query )
                                                        }),
                     {
                          headers: { "Accept": "application/json" },
                          handleAs: "json",
                          failOk: true
                     })
                .then( function(o) {
                           thisB._resultsToFeatures( o, featCallback );
                           finishCallback();
                       },
                       lang.hitch( this, '_failAllDeferred' )
                     );
        } else {
            finishCallback();
        }
    },

    _resultsToFeatures: function( results, featCallback ) {
        var rows = ((results||{}).results||{}).bindings || [];
        if( ! rows.length )
            return;
        var fields = results.head.vars;
        var requiredFields = ['gene_id', 'gene_type', 'gene_start', 'gene_end', 'feat_id', 'feat_type', 'feat_start', 'feat_end', 'exon_id', 'exon_type', 'exon_start', 'exon_end', 'strand'];
       for( var i = 0; i < requiredFields.length; i++ ) {
            if( fields.indexOf( requiredFields[i] ) == -1 ) {
                console.error("Required field "+requiredFields[i]+" missing from feature data");
                return;
            }
        };
        var seenFeatures = {};
        array.forEach( rows, function( row ) {
            var data = {};
            array.forEach( fields, function(field) {
                if( field in row )
                    data[field] = row[field].value;
            });
            // (sub)feature: { id: <uri>, data: { start: ##, end: ##, strand: #, name: "...", descrption: "...", subfeatures: [] } }
            var g = seenFeatures[data.gene_id] || { data: { subfeatures: [] } };
            var f = seenFeatures[data.feat_id] || { data: { subfeatures: [] } };
            var e = seenFeatures[data.exon_id] || { data: { subfeatures: [] } };
            // gene
            if(! g.id ) {
                g.id = data.gene_id;
                g.data.type = data.gene_type;
                g.data.start = parseInt( data.gene_start );
                g.data.end = parseInt( data.gene_end );
                g.data.strand = parseInt( data.strand );
                if( data.gene_name || data.feat_name )
                    g.data.name = data.gene_name || data.feat_name;
                if( data.gene_description || data.feat_description )
                    g.data.description = data.gene_description || data.feat_description;
                seenFeatures[g.id] = g;
            }
            // feature (CDS, tRNA, rRNA etc.)
            if(! f.id ) {
                f.id = data.feat_id;
                f.data.parent = data.gene_id;
                f.data.type = data.feat_type;
                f.data.start = parseInt( data.feat_start );
                f.data.end = parseInt( data.feat_end );
                f.data.strand = parseInt( data.strand );
                if( data.feat_name )
                    f.data.name = data.feat_name;
                if( data.feat_description )
                    f.data.description = data.feat_description;
                seenFeatures[f.id] = f;
            }
            // exon
            e.id = data.exon_id;
            e.data.type = data.exon_type;
            e.data.parent = data.feat_id;
            e.data.start = parseInt( data.exon_start );
            e.data.end = parseInt( data.exon_end );
            e.data.strand = parseInt( data.strand );
            seenFeatures[e.id] = e;
        }, this);

        // resolve subfeatures, keeping only top-level features in seenFeatures
        for( var id in seenFeatures ) {
            var f = seenFeatures[id];
            var pid = f.data.parent;
            if( pid ) {
                //console.log("id>> " + id)
                //console.log("pid>> " + pid)
                delete f.data.parent;
                var p = seenFeatures[pid];
                if( p ) {
                    p.data.subfeatures.push( f.data );
                    //delete seenFeatures[id];
                    f.data.seen = true;
                }
            }
        }

        for( var id in seenFeatures ) {
            if(! seenFeatures[id].data.seen ) {
                //console.log("id>> " + id)
                featCallback( new SimpleFeature( seenFeatures[id] ) );
            }
        }
    }
});

});

