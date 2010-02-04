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


private     import  ocean.db.c.tokyocabinet_hash;
private     import  tango.stdc.stdlib;
private     import  tango.stdc.string: strlen;


/*******************************************************************************

        Tokyo Cabinet Database
        
        Very fast and lightweight database with 10K to 200K inserts per second
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
        

*******************************************************************************/

class TokyoCabinet
{
    
    /**************************************************************************
     
        Tokyo Cabinet put function definition
        
        The following Tokyo Cabinet functions comply to TchPutFunc:
        
        ---
        
            tchdbput()
            tchdbputkeep()
            tchdbputcat()
            tchdbputasync()

        ---
        
     **************************************************************************/
    
    extern (C) 
    {
        private alias bool function ( TCHDB *hdb, void *key, int ksiz, 
                void *value, int vsiz ) TchPutFunc;
    }
    
    /**************************************************************************
        
        Definitions
    
     **************************************************************************/ 
    
    private         TCHDB*          db;                             // tokyocabinet instance
    private         bool            async = false;                  // disable by default
    
    /**************************************************************************
        
        Tuning parameter for hash database tchdbtune
    
     **************************************************************************/ 
    
    private         long            tune_bnum; //  = 30_000_000;       
    private         byte            tune_apow; //   = 2;
    private         byte            tune_fpow; //   = 3;
    private         TuneOpts        tune_opts;         
    

    /**************************************************************************
        
        constants for tchdbtune options
    
        Large:      size of the database can be larger than 2GB 
        Deflate:    each recordis compressed with deflate encoding
        Bzip:       each record is compressed with BZIP2 encoding
        Tcbs:       each record is compressed with TCBS encoding
    
     **************************************************************************/
    
    enum                            TuneOpts : HDBOPT
                                    {
                                        Large   = HDBOPT.HDBTLARGE, 
                                        Deflate = HDBOPT.HDBTDEFLATE,
                                        Bzip    = HDBOPT.HDBTBZIP,
                                        Tcbs    = HDBOPT.HDBTTCBS,
                                        
                                        None    = cast (HDBOPT) 0
                                    }
    
    /**************************************************************************
    
        Destructor check if called twice

     **************************************************************************/
    bool            deleted         = false;
    
    
    /**************************************************************************
        
        Constructor    
        
        Params:
            dbfile = path to database file (e.g. /tmp/store.tch)
                             
     **************************************************************************/
    
    public this ( ) 
    {
        this.db = tchdbnew();
        
        // tchdbsetxmsiz(db, 500_000_000); // set memory used in bytes
        // set elements * 0,5 to 4 times
        // tchdbtune(db, 20_000_000, 4, 10, HDBTLARGE);
    }
    
    /**************************************************************************
    
        Destructor    
        
        FIXME: destructor called twice: why?
        
        tchdbdel() will close the database object if it is still open.
                             
     **************************************************************************/

    ~this ( )
    {
        if (!deleted)
        {
            tchdbdel(this.db);
        }
        
        this.deleted = true;
    }
    
    /**************************************************************************
        
        Invariant: called every time a public class method is called
                             
     **************************************************************************/
    
    invariant ( )
    {
        assert (this.db, typeof (this).stringof ~ ": invalid Tokyo Cabinet core object");
    }
    
    
    /**************************************************************************
    
        Open Database

        dbfile = specifies the database  file name
  
     **************************************************************************/    
    
    public void open ( char[] dbfile )
    {   
        tchdbtune(this.db, this.tune_bnum, this.tune_apow, this.tune_fpow, this.tune_opts);
        
        this.tokyoAssert(tchdbopen(this.db, this.toCstring(dbfile).ptr, 
                                   HDBOMODE.HDBOWRITER |
                                   HDBOMODE.HDBOCREAT  |
                                   HDBOMODE.HDBOLCKNB), "Open error");
    }
    
    
    /**************************************************************************
        
        Close Database
    
    ***************************************************************************/
    
    public void close ()
    {
        if (this.db)
        {
            this.tokyoAssert(tchdbclose(this.db), "close error");
        }
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
        tchdbsetmutex(this.db);
    }

    
    /**************************************************************************
    
        Set number of elements in bucket array 
        
        Params:
            bnum = number or initial records (init size)
            
    ***************************************************************************/
    
    public void setTuneBnum ( uint bnum = tune_bnum.init )
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
    
    public void setTuneOpts ( TuneOpts opts = tune_opts.init )
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
    
    public void put ( char[] key, char[] value )
    {
        this.tchPut(key, value, this.async? &tchdbputasync : &tchdbput);
    }
    
    public alias put opIndexAssign;
    
    /+
    public bool put ( char[] key, char[] value )
    {
        return this.async?
            tchdbputasync(this.db, key.ptr, key.length, value.ptr, value.length) :
            tchdbput     (this.db, key.ptr, key.length, value.ptr, value.length);
            
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
    +/
    
    /**************************************************************************
    
        Push Key/Value Pair to Database
       
        Params:
            key = hash key
            value = key value
            
        Returns:
            true if successful concenated, false on error
            
    ***************************************************************************/

    
    public void putkeep ( char[] key, char[] value )
    {
        this.tchPut(key, value, &tchdbputkeep);
    }
    
    
    /**************************************************************************
        
        Attach/Concenate Value to Key
        
        Params:
            key = hash key
            value = value to concenate to key
            
        Returns:
            true if successful concenated, false on error
            
    ***************************************************************************/
    
    public void putcat ( char[] key, char[] value )
    {
        this.tchPut(key, value, &tchdbputcat);
    }
    
    
    /**************************************************************************
        
        Get Value
    
        Params:
            key = lookup hash key
    
        Returns
            value of key
            
    ***************************************************************************/
    /+
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
        free(cvalue);                       // allocated by tchdbget2()
        
        return this.tmp_buffer;
    }
    +/
    
    /**************************************************************************
    
        Get Value of Key without heap activity using free
    
        Params:
            key = hash key
            value = return buffer for value
            
        Returns:
            true if key found, otherwise false
            
    ***************************************************************************/
    
    
    public bool get ( char[] key, out char[] value )
    {
        int length;
        
        void* cvalue = tchdbget(this.db, key.ptr, key.length, &length);
        
        if (cvalue)
        {
            value = (cast (char*) cvalue)[0 .. length].dup;
            
            free(cvalue);  // allocated by tchdbget()
            
            return true;
        }
        
        return false;
    }
    
    
    /**************************************************************************
    
        Get Value of Key without heap activity using free
    
        Params:
            key = hash key
    
        Returns
            value or empty string if item not existing
            
    ***************************************************************************/
    
    public char[] get ( char[] key )
    {
        int length;
        
        void* cvalue = tchdbget(this.db, key.ptr, key.length, &length);
        
        if (cvalue)
        {
            scope (exit) free(cvalue);  // allocated by tchdbget()
            
            return (cast (char*) cvalue)[0 .. length].dup;
        }
        
        return "";
    }
    
    
    /**************************************************************************
    
        Get Value of Key without intermediate value buffer
    
        Params:
            key   = hash key
            value = value output
    
        Returns
            true on success or false if item not existing
            
    ***************************************************************************/

    public bool get_alt ( char[] key, out char[] value )
    {
        int length = tchdbvsiz(this.db, key.ptr, key.length);
        
        bool found = length >= 0;
        
        if (found)
        {
            value.length = length;
            
            found = (tchdbget3(this.db, key.ptr, key.length, value.ptr, length) >= 0);
            
            if (!found)
            {
                value.length = 0;
            }
        }
        
        return found;
    }
    
    
    /**************************************************************************
    
        Get Value of Key via indexing. 
    
    ***************************************************************************/

    public char[] opIndex ( char[] key )
    {
        char[] value;
        
        this.get_alt(key, value);
        
        return value.dup;
    }
    
    
    /**************************************************************************
    
        Remove item
        
        Params:
            key = key of item to remove
        
        Returns:
            true on success or false otherwise
        
    ***************************************************************************/

    public bool remove ( char[] key )
    {
        return tchdbout(this.db, key.ptr, key.length);
    }
    
    
    /**************************************************************************
    
        Iterate through database and return key
        
        Iterator needs to be initialized before it can be used!
        
        @see reference
        
        http://torum.net/2009/10/iterating-tokyo-cabinet-in-parallel/
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        Returns:
            true, if iterator could be initialized, false on error 
       
    ***************************************************************************/
    
    public void initIterator ()
    {
        this.tokyoAssert(tchdbiterinit(this.db), "Error initializing Iterator"); 
    }
    
    
    /**************************************************************************
        
        Returns the next key from the iterator
        
        The iterator needs to be initialized with initIterator key needs to be 
        deleted, because on every iteration a new malloc is made by the tokyo 
        cabinet library.
        
        @see refererence
         
        http://torum.net/2009/10/iterating-tokyo-cabinet-in-parallel/
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
        Params:
            dst = return buffer for next element
        
        Returns: 
            true, if next item is available false, otherwise
        
    ***************************************************************************/
    
    public void iterNext ( out char[] dst )
    {
        char* key = tchdbiternext2(this.db);
        
        tokyoAssert(key, "Error on iteration");
        
        dst = toDString(key).dup;
        free(key);
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
    
    public int opApply ( TchDbIterator.ForeachDelg delg )
    {
        return TchDbIterator.tchdbopapply(this.db, delg);
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
    
    
    
    /**************************************************************************
    
        Invokes put_func to put key/value into the database.
        
        The following Tokyo Cabinet functions comply to TchPutFunc:
        
            tchdbput
            tchdbputkeep
            tchdbputcat
            tchdbputasync
        
        Params:
            key      = key of item to put
            value    = item value
            put_func = Tokyo Cabinet put function
        
    ***************************************************************************/

   
    private void tchPut ( char[] key, char[] value, TchPutFunc put_func )
    in
    {
        assert (key,   "Error on put: null key");
        assert (value, "Error on put: null value");
    }
    body
    {
        this.tokyoAssert(put_func(this.db, key.ptr, key.length, value.ptr, value.length),
                         "Error on put");
    }

    
    /**************************************************************************
    
        Retrieves the current Tokyo Cabinet error message string.
        
        Returns:
            current Tokyo Cabinet error message string
        
    ***************************************************************************/

    private char[] getTokyoErrMsg ( )
    {
        return this.getTokyoErrMsg(tchdbecode(this.db));
    }
    
    
    /**************************************************************************
    
        Retrieves the Tokyo Cabinet error message string for errcode.
        
        Params:
            errcode = Tokyo Cabinet error code
            
        Returns:
            Tokyo Cabinet error message string for errcode
        
    ***************************************************************************/

    private char[] getTokyoErrMsg ( TCHERRCODE errcode )
    {
        return toDString(tchdberrmsg(errcode));
    }
    
    
    /**************************************************************************
    
        Asserts p is not null; p == null is considered an error reported by
        Tokyo Cabinet.
        
        Params:
            p       = not null assertion pointer
            context = error context description string for message
        
    ***************************************************************************/
    
    private void tokyoAssert ( void* p, char[] context = "Error" )
    {
        this.tokyoAssert(!!p, context);
    }

    /**************************************************************************
    
        Asserts ok; ok == false is considered an error reported by Tokyo
        Cabinet.
        
        Params:
            ok      = assert condition
            context = error context description string for message
        
    ***************************************************************************/

    private void tokyoAssert ( bool ok, char[] context = "Error" )
    {
        if (!ok)
        {
            TCHERRCODE errcode = tchdbecode(this.db);
            
            if (errcode != TCHERRCODE.TCESUCCESS)
            {
                TokyoCabinetException(typeof (this).stringof ~ ": " ~
                                      context ~ ": " ~ this.getTokyoErrMsg(errcode));
            }
        }
    }
    
    
    /**************************************************************************
    
        Converts str to a C string, that is, a null terminator is appended if
        not present.
        
        Params:
            str = input string
        
        Returns:
            C compatible (null terminated) string
        
    ***************************************************************************/

    private static char[] toCstring ( char[] str )
    {
        bool term = str.length? !!str[$ - 1] : true;
        
        return term? str ~ '\0' : str;
    }
    
    /**************************************************************************
    
        Converts str to a D string: str is sliced from beginning to its null
        terminator.
        
        Params:
            str = C compatible input string (pointer to first element of null
                  terminated string)
        
        Returns:
            C compatible (null terminated) string
        
    ***************************************************************************/

    private static char[] toDString ( char* str )
    {
        return str? str[0 .. strlen(str)] : "";
    }
}


/*******************************************************************************

    PersistentQueueException

*******************************************************************************/

class TokyoCabinetException : Exception
{
    public this ( char[] msg ) { super(msg); }
    
    protected static void opCall ( char[] msg ) { throw new TokyoCabinetException(msg); }
}


