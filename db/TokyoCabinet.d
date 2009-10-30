/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff

*******************************************************************************/

module db.TokyoCabinet;


/*******************************************************************************

    Imports

********************************************************************************/

//private import ocean.db.c.tokyocabinet;
private     import  ocean.db.c.tokyocabinet_hash;

private     import  tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;
private     import  tango.stdc.stdlib;

//private     import  tango.util.log.Trace;


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
    
    ***************************************************************************/ 
    
    private         char[]          dbfile;                         // database name
    private         TCHDB*          db;                             // tokyocabinet instance
    private         bool            async = false;                  // disable by default
    
    
    /**************************************************************************
        
        tuning parameter for hash database tchdbtune
    
    ***************************************************************************/ 
    
    private         long            tune_bnum   = 30_000_000;       
    private         byte            tune_apow   = 2;
    private         byte            tune_fpow   = 3;
    private         ubyte           tune_opts;         
    

    /**************************************************************************
        
        constants for tchdbtune options
    
    ***************************************************************************/
    
    const           enum            TUNEOPTS : ubyte
                                    {
                                        HDBTLARGE, 
                                        HDBTDEFLATE,
                                        HDBTBZIP,
                                        HDBTTCBS,        
                                    }
    
    
    /**************************************************************************
        
        Buffer
    
    ***************************************************************************/
    
    private         char[]          tmp_buffer;
    
    
    
    /**************************************************************************
        
        Constructor    
        
        Params:
            dbfile = path to database file (e.g. /tmp/store.tch)
                             
    ***************************************************************************/
    
    public synchronized this ( char[] dbfile ) 
    {
        this.dbfile = dbfile;
        this.db = tchdbnew();
        
        // tchdbsetxmsiz(db, 500_000_000); // set memory used in bytes
        // set elements * 0,5 to 4 times
        // tchdbtune(db, 20_000_000, 4, 10, HDBTLARGE);
    }
    
    
    /**************************************************************************
    
        Open Database

        apow = specifies the size of record alignment by power of 2.
        fpow = specifies the maximum number of elements of the free block 
               pool by power of 2.
        opts = specifies options by bitwise-or
  
    ***************************************************************************/    
    
    public synchronized void open ()
    {   
        // Tune database before opening database
        tchdbtune(this.db, this.tune_bnum, 
            this.tune_apow, this.tune_fpow, this.tune_opts);
        
        if (!tchdbopen(this.db, toCString(this.dbfile), 
            HDBOWRITER | HDBOCREAT | HDBOLCKNB))
            {
                TokyoCabinetException("open error");
            }
    }
    
    
    /**************************************************************************
        
            Close Database
    
    ***************************************************************************/
    
    public synchronized void close ()
    {
        if (this.db !is null)
            if (!tchdbclose(this.db))
                TokyoCabinetException("close error");
    }
    
    
    /**************************************************************************
        
        Enable asynchronous write
    
    ***************************************************************************/ 
    
    public void enableAsync ()
    {
        this.async = true;
    }
    
    
    /**************************************************************************
        
        Set Mutex for Threading (call before opening)
    
    ***************************************************************************/
    
    public void enableThreadSupport ()
    {
        if (this.db !is null)
            tchdbsetmutex(this.db);
    }

    
    /**************************************************************************
    
        Set number of elements in bucket array 
        
        Params:
            bnum = number or initial records (init size)
            
    ***************************************************************************/
    
    public void setTuneBnum ( uint bnum )
    {
        this.tune_bnum = bnum;
    }
    
    
    /**************************************************************************
    
        Set Database Options
        
        HDBTLARGE:      size of the database can be larger than 2GB 
        HDBTDEFLATE:    each recordis compressed with deflate encoding
        HDBTBZIP:       each record is compressed with BZIP2 encoding
        HDBTTCBS:       each record is compressed with TCBS encoding
        
        setTuneOpts(HDBTLARGE);
        setTuneOpts(HDBTLARGE|HDBTDEFLATE);       
                
        Params:
            opts = tune options
            
    ***************************************************************************/
    
    public void setTuneOpts ( ubyte opts )
    {
        this.tune_opts = HDBTLARGE;
    }
    
    
    /**************************************************************************
        
        Set number of elements in bucket array
        
        Set cache size of database before opening.
        
        Params:
            size = cache size in bytes
            
    ***************************************************************************/
    
    
    public void setCacheSize( uint size )
    {
        if (this.db !is null)
            tchdbsetcache(this.db, size);
    }
    
    
    /**************************************************************************
        
        Set memory size
        
        Set size of memory used by database before opening.
        
        Params:
            size = mem size in bytes
            
    ***************************************************************************/
    
    
    public void setMemSize( uint size )
    {
        if (this.db !is null)
            tchdbsetxmsiz(this.db, size);
    }
    
    
    /**************************************************************************
     
        Push Key/Value Pair to Database
       
        Params:
            key = hash key
            value = key value
            
        Returns:
            true if successful concenated, false on error
            
    ***************************************************************************/
    
    public bool add ( char[] key, char[] value )
    in
    {
        assert(key);
    }
    body
    {
        // I should try it with malloc() to get arround the GC
        //tchdbmemsync(this.db, true);
        if ( this.async )
        {   
            if (!tchdbputasync2(this.db, toCString(key), toCString(value)))
            {
//                TokyoCabinetException("async write error");
//                Trace.formatln("TokyoCabinet Write Error {}", toDString(tchdberrmsg(tchdbecode(this.db))));
                
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
        
        Params:
            key = hash key
            value = value to concenate to key
            
        Returns:
            true if successful concenated, false on error
            
    ***************************************************************************/
    
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
            return false;
        }

        return true;    
    }
    
    
    /**************************************************************************
        
        Get Value
    
        Params:
            key = lookup hash key
    
        Returns
            value of key
            
    ***************************************************************************/
    
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
//            Trace.formatln("TokyoCabinet Get Error: '{}'", toDString(tchdberrmsg(tchdbecode(this.db))));
            return null;
        }
        
        tmp_buffer = toDString(cvalue).dup;
        free(cvalue);
        
        return tmp_buffer;
    }
    
    
    /**************************************************************************
    
        Get Value of Key without heap activity using free
    
        Params:
            key = hash key
            value = return buffer for value
    
        Returns
            true on success, false on error
            
    ***************************************************************************/
    
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
//            Trace.formatln("TokyoCabinet Get Error: '{} {}'", key, toDString(tchdberrmsg(tchdbecode(this.db))));
            return false;
        }
        
        value = toDString(cvalue).dup;
        free(cvalue);
        
        return true;
    }
    
    
    /**************************************************************************
    
        Iterate through database and return key
        
        Iterator needs to be initialized before it can be used!
        
        @see reference
        
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        Returns:
            true, if iterator could be initialized, false on error 
       
    ***************************************************************************/
    
    public bool initIterator ()
    {
        if (tchdbiterinit(this.db) != true) 
        {
            TokyoCabinetException("TokyoCabinet failed to init Iterator: '" ~ 
                toDString(tchdberrmsg(tchdbecode(this.db))) ~ "'");
            
//            return false;
        }
        
        return true;
    }
    
    
    /**************************************************************************
        
        Returns the next key from the iterator
        
        The iterator needs to be initialized with initIterator key needs to be 
        deleted, because on every iteration a new malloc is made by the tokyo 
        cabinet library.
        
        @see refererence
         
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        Params:
            dst = return buffer for next element
        
        Returns: 
            true, if next item is available false, otherwise
        
    ***************************************************************************/
    
    public bool iterNext ( ref char[] dst )
    {
        char* key;        
        
        if ((key = tchdbiternext2(this.db)) is null)
        {
            TokyoCabinetException("TokyoCabinet Iterator Error: '" ~ 
                toDString(tchdberrmsg(tchdbecode(this.db))) ~ "'");
            
//            return false;
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


