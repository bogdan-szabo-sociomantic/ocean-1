/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module db.TokyoCabinet;

//private import ocean.db.c.tokyocabinet;
private     import  ocean.db.c.tokyocabinet_hash;

private     import  tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;
private     import  tango.stdc.stdlib;

private     import  tango.util.log.Trace;




/*******************************************************************************

        Tokyo Cabinet Database
        
        Very fast and lightwight database with 10K to 200K inserts per second
        based on the storage engine used.
        
        ---
        
        import ocean.db.TokyoCabinet;
        
        auto db = new TokyoCabinet("db.tch");
        db.setTuneOpts(TokyoCabinet.TUNEOPTS.HDBTLARGE);
        db.setTuneBnum(20_000_000);
        db.enableAsync();
        db.open();
        
        db.add("foo", "bar");
        
        db.close;
        
        ---
        
        We should use this database in combination with the FNV  
        hash algorithm in order to build a distributed hash table (DTH)
        
        References
        
        http://www.audioscrobbler.net/development/ketama/
        svn://svn.audioscrobbler.net/misc/ketama/
        http://pdos.csail.mit.edu/chord/
        
        TODO Iteration
        
        http://torum.net/2009/10/iterating-tokyo-cabinet-in-parallel/
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        ---

*******************************************************************************/

class TokyoCabinet
{
        
    /**************************************************************************
        
        Definitions
    
     **************************************************************************/ 
    
    private         char[]          dbfile;                         // database name
    private         TCHDB*          db;                             // tokyocabinet instance
    private         bool            async = false;                  // disable by default
    //private         int             counter;                      // counter for flushing async
    
    
    // tuning parameter for hash database tchdbtune    
    private         long            tune_bnum   = 30_000_000;       
    private         byte            tune_apow   = 2;
    private         byte            tune_fpow   = 3;
    private         ubyte           tune_opts;         
    
    // constants for tchdbtune options    
    const           enum            TUNEOPTS : ubyte
                                    {
                                        HDBTLARGE, 
                                        HDBTDEFLATE,
                                        HDBTBZIP,
                                        HDBTTCBS,        
                                    }
    
    private         char[]          tmp_buffer;
    
    
    
    /**************************************************************************
        
        Constructor    
        
        dbfile  = path to database file (e.g. /tmp/store.tch)
        bnum    = specifies the number of elements of the bucket array. Suggested 
                  size of the bucket array is about from 0.5 to 4 times of the 
                  number of all records to be stored.
                             
     **************************************************************************/
    
    
    public this ( char[] dbfile ) 
    {
        this.dbfile = dbfile;
        this.db = tchdbnew();
        
        // set memory used in bytes
        tchdbsetxmsiz(db, 500_000_000);
        
        // set elements * 0,5 to 4 times
        //tchdbtune(db, 20_000_000, 4, 10, HDBTLARGE);
        
        
    }
    
    
    /**************************************************************************
    
            Open Database

            apow = specifies the size of record alignment by power of 2.
            fpow = specifies the maximum number of elements of the free block 
                   pool by power of 2.
            opts = specifies options by bitwise-or
  
     **************************************************************************/    
    
    
    public void open ()
    {   
        // Tune database before opening database
        tchdbtune(this.db, this.tune_bnum, this.tune_apow, this.tune_fpow, this.tune_opts);
        
        if (!tchdbopen(this.db, toCString(this.dbfile), HDBOWRITER | HDBOCREAT | HDBOLCKNB))
        {
            TokyoCabinetException("open error");
        }
    }
    
    
    /**************************************************************************
        
            Close Database
    
     **************************************************************************/
    
    
    public void close ()
    {
        if (!tchdbclose(this.db))
        {
            TokyoCabinetException("close error");
        }
    }
    
    
    /**************************************************************************
        
        Enable asynchronous write
    
     **************************************************************************/
    
    
    public void enableAsync ()
    {
        this.async = true;
    }
    
    
    /**************************************************************************
        
        Set Mutex for Threading (call before opening)
    
     **************************************************************************/
    
    
    public void enableThreadSupport ()
    {
        tchdbsetmutex(this.db);
    }

    
    /**************************************************************************
    
        Set number of elements in bucket array 

     **************************************************************************/
    
    public void setTuneBnum ( uint bnum )
    {
        this.tune_bnum = bnum;
    }
    
    
    /**************************************************************************
    
        Set specific options for database opening
        HDBTLARGE:      specifies that the size of the database can be larger than 2GB 
        HDBTDEFLATE:    specifies that each recordis compressed with Deflate encoding
        HDBTBZIP:       specifies that each record is compressed with BZIP2 encoding
        HDBTTCBS:       specifies that each record is compressed with TCBS encoding
        
        setTuneOpts(HDBTLARGE);
        setTuneOpts(HDBTLARGE|HDBTDEFLATE);               
    
     **************************************************************************/
    
    
    public void setTuneOpts ( ubyte opts )
    {
        this.tune_opts = HDBTLARGE;
    }
    
    
    /**************************************************************************
        
        Set number of elements in bucket array 
    
     **************************************************************************/
    
    
    public void setCacheSize( uint size )
    {
        tchdbsetcache(this.db, size);
    }
    
    
    /**************************************************************************
     
           Push Key/Value Pair to Database
       
     **************************************************************************/
    
    
    public bool add ( char[] key, char[] value )
    in
    {
        assert(key);
        assert(value);
    }
    body
    {
        
        // I should try it with malloc() to get arround the GC
        //tchdbmemsync(this.db, true);
        if ( this.async )
        {
            //counter++;
            
            //if ( !tchdbputasync2(this.this.db, toCString("00000000000000"), toCString("1111111111111111")) )
            if (!tchdbputasync2(this.db, toCString(key), toCString(value)))
                //TokyoCabinetException("async write error");
            {
                Trace.formatln("TokyoCabinet Write Error {}", toDString(tchdberrmsg(tchdbecode(this.db))));
                
                return false;
            }           
        }
        else
        {
            if (!tchdbput2(this.db, toCString(key), toCString(value)))
                //TokyoCabinetException("write error");
                return false;
        }
        
        return true;
    }
    
    
    
    /**************************************************************************
        
        Attach/Concenate Value to Key
    
     **************************************************************************/
    
    
    public bool addconcat ( char[] key, char[] value )
    in
    {
        assert(key);
        assert(value);
    }
    body
    {   
        if (!tchdbputcat2(this.db, toCString(key), toCString(value)))
        {
           //  Trace.formatln("out ").flush();
            return false;
        }

        // Trace.formatln("in  ").flush();
        return true;    
    }
    
    
    /**************************************************************************
        
            Get Value of Key
    
     **************************************************************************/
    
    
    public char[] get ( char[] key )
    in
    {
        assert(key);
    }
    body
    {
        char* cvalue;
        
        if ((cvalue = tchdbget2(this.db, toCString(key))) is null) 
        {
            Trace.formatln("TokyoCabinet Get Error: '{}'", toDString(tchdberrmsg(tchdbecode(this.db))));
            return null;
        }
        
        tmp_buffer = toDString(cvalue).dup;
        free(cvalue);
        
        return tmp_buffer;
    }
    
    
    /**************************************************************************
    
        Get Value of Key without heap activity using free
    
     **************************************************************************/
    
    
    public bool get ( char[] key, inout char[] value )
    in
    {
        assert(key);
    }
    body
    {
        char* cvalue;
        
        if ((cvalue = tchdbget2(this.db, toCString(key))) is null)
        {
            Trace.formatln("TokyoCabinet Get Error: '{} {}'", key, toDString(tchdberrmsg(tchdbecode(this.db))));
            return false;
        }
        
        value = toDString(cvalue).dup;
        free(cvalue);
        
        return true;
    }
    
    
    /**************************************************************************
    
        Iterate through database and return key
        
        Iterator needs to be initialized before it can be used!
        
        @see http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
     **************************************************************************/

    
    public bool initIterator ()
    {
        if (tchdbiterinit(this.db) != true) 
        {
            Trace.formatln("TokyoCabinet failed to init Iterator: '{}'", toDString(tchdberrmsg(tchdbecode(this.db))));
            return false;
        }
        
        return true;
    }
    
    
    /**************************************************************************
        
        Returns the next key from the iterator
        
        The iterator needs to be initialized with initIterator key needs to be 
        deleted, because on every iteration a new malloc is made by the tokyo 
        cabinet library.
        
        @see http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        Returns: true, if next item is available false, otherwise
        
     **************************************************************************/

    
    public bool iterNext ( inout char[] dst )
    {
        char* key;        
        
        if ((key = tchdbiternext2(this.db)) is null)
        {
            Trace.formatln("TokyoCabinet Iterator Error: '{}'", toDString(tchdberrmsg(tchdbecode(this.db))));
            return false;
        }        
        
        dst = toDString(key).dup;
        free(key);
        
        return true;
    }
    
    
}


/*******************************************************************************

    PersistentQueueException

*******************************************************************************/

class TokyoCabinetException : Exception
{
    this(char[] msg)
    {
        super(msg);
    }
    
    protected:
        static void opCall(char[] msg) { throw new TokyoCabinetException(msg); }
}


