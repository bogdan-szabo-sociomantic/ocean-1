/******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff

 *******************************************************************************/

module db.TokyoCabinet;


/******************************************************************************

    Imports

 ******************************************************************************/

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
        db.setTuneOpts(TokyoCabinet.TuneOpts.HDBTLARGE);
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
        
        Iteration
        
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
    
        Large:      size of the database can be larger than 2GB 
        Deflate:    each recordis compressed with deflate encoding
        Bzip:       each record is compressed with BZIP2 encoding
        Tcbs:       each record is compressed with TCBS encoding
    
    ***************************************************************************/
    
    const           enum            TuneOpts : HDBOPTS
                                    {
                                        Large   = HDBOPTS.HDBTLARGE, 
                                        Deflate = HDBOPTS.HDBTDEFLATE,
                                        Bzip    = HDBOPTS.HDBTBZIP,
                                        Tcbs    = HDBOPTS.HDBTTCBS,
                                        
                                        None    = cast (HDBOPTS) 0
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
    
    public this ( char[] dbfile ) 
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
    
    public void open ( )
    {   
        // Tune database before opening database
        tchdbtune(this.db, this.tune_bnum, 
            this.tune_apow, this.tune_fpow, this.tune_opts);
        
        if (!tchdbopen(this.db, toCString(this.dbfile), 
            HDBOMODE.HDBOWRITER | HDBOMODE.HDBOCREAT | HDBOMODE.HDBOLCKNB))
            {
                TokyoCabinetException("open error");
            }
    }
    
    
    /**************************************************************************
        
            Close Database
    
    ***************************************************************************/
    
    public void close ()
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
    in
    {
        assert (!this.db, typeof (this).stringof ~ ".enableThreadSupport(): "
                          "cannot enable thread support after open() has been "
                          "called");
    }
    body
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
        
        TuneOpts.Large:      size of the database can be larger than 2GB 
        TuneOpts.Deflate:    each recordis compressed with deflate encoding
        TuneOpts.Bzip:       each record is compressed with BZIP2 encoding
        TuneOpts.Tcbs:       each record is compressed with TCBS encoding
        
        Options may be combined by bit-wise OR '|':
                
        ---
        
            setTuneOpts(TuneOpts.Large);
            setTuneOpts(TuneOpts.Large | TuneOpts.Deflate);       
        
        ---
        
        Params:
            opts = tune options
            
    ***************************************************************************/
    
    public void setTuneOpts ( TuneOpts opts )
    {
        this.tune_opts = opts;
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
    
    public bool put ( char[] key, char[] value )
    in
    {
        assert(key);
    }
    body
    {
        return this.async?
            tchdbputasync2(this.db, toCString(key), toCString(value)) :
            tchdbput2     (this.db, toCString(key), toCString(value));
                
        /*
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
        */
    }
    
    
    /**************************************************************************
    
        Push Key/Value Pair to Database
       
        Params:
            key = hash key
            value = key value
            
        Returns:
            true if successful concenated, false on error
            
    ***************************************************************************/

   
    public bool putkeep ( char[] key, char[] value )
    in
    {
        assert(key);
    }
    body
    {
        return tchdbputkeep2(this.db, toCString(key), toCString(value));
    }
    
    
    /**************************************************************************
        
        Attach/Concenate Value to Key
        
        Params:
            key = hash key
            value = value to concenate to key
            
        Returns:
            true if successful concenated, false on error
            
    ***************************************************************************/
    
    public bool putcat ( char[] key, char[] value )
    in
    {
        assert(key);
        assert(value);
    }
    body
    {   
        return tchdbputcat2(this.db, toCString(key), toCString(value));
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
        
        this.tmp_buffer = toDString(cvalue).dup;
        free(cvalue);
        
        return this.tmp_buffer;
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
    
    
    /**************************************************************************
    
        Returns the next key/value pair from the iterator
        
        The iterator needs to be initialized with initIterator key needs to be 
        deleted, because on every iteration a new malloc is made by the tokyo 
        cabinet library.
        
        @see refererence
         
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        Params:
            key   = return buffer for next key
            value = return buffer for next value
        
        Returns: 
            true, if next item is available false, otherwise
    
     ***************************************************************************/

    public bool iterNext ( ref char[] key, ref char[] value )
    {
        char* _value = null;
        
        char* _key = tchdbiternext2(this.db);
        
        if (_key)
        {
            _value = tchdbget2(this.db, _key);
            
            key = toDString(_key).dup;
            
            if (_value)
            {
                value = toDString(_value).dup;
            }
        }
            
        return !!_value;
    }
    
    
    /**************************************************************************
    
        "foreach" iterator over items in database. The "key" and "val"
        parameters of the delegate correspond to the iteration variables.
        
        Usage:
        
        ---
        
            import ocean.db.TokyoCabinet;
        
            auto db = new TokyoCabinet("db.tch");
            db.open();
            
            foreach (key, val; db)
            {
                // "key" and "val" contain the key and value of the current item
            }
            
            db.close();

            
        ---
    
     ***************************************************************************/
    
    public int opApply ( int delegate ( ref char[] key, ref char[] value ) dg )
    {
        int result = 0;
        
        char[] key, value;
        
        this.initIterator();
        
        while (this.iterNext(key, value) && !result)
        {
            result = dg(key, value);
        }
        
        return result;
    }
    
    
    /**************************************************************************
        
        Returns number of records
        
        Returns: 
            number of records, or zero if none
        
    ***************************************************************************/
    
    public ulong numRecords ()
    {
        return tchdbrnum(this.db);
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


