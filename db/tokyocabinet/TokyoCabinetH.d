/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt

 ******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetH;


/*******************************************************************************

    Imports

 ******************************************************************************/


public      import 	ocean.core.Exception: TokyoCabinetException;

private     import  ocean.db.tokyocabinet.c.tchdb;

private     import  tango.stdc.stdlib: free;
private     import  tango.stdc.string: strlen;

private     import  tango.util.log.Trace;


/*******************************************************************************

        Tokyo Cabinet Hash Database
        
        Very fast and lightweight database with 10K to 200K inserts per second
        based on the storage engine used.
        
        ---
        
        import ocean.db.tokyocabinet.TokyoCabinetH;
        
        auto db = new TokyoCabinetH();
        db.setTuneOpts(TokyoCabinetH.TuneOpts.HDBTLARGE);
        db.setTuneBnum(20_000_000);
        db.enableAsync();
        db.open("db.tch");
        
        db.add("foo", "bar");
        
        db.close;
        
        ---
        

*******************************************************************************/

class TokyoCabinetH
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
    
    extern (C) private alias bool function ( TCHDB *hdb, void *key, int ksiz, 
                                              void *value, int vsiz ) TchPutFunc;
    
    /**************************************************************************
        
        Definitions
    
     **************************************************************************/ 
    
    private         TCHDB*          db;                             			// tokyocabinet instance
    private         bool            async = false;                  			// disable by default
    
    /**************************************************************************
        
        Tuning parameter for hash database tchdbtune
    
     **************************************************************************/ 
    
    private         long            tune_bnum; 									//  = 30_000_000;       
    private         byte            tune_apow; 									//   = 2;
    private         byte            tune_fpow; 									//   = 3;
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
    
    enum                            OpenStyle : HDBOMODE
                                    {
                                        Read             = HDBOMODE.HDBOREADER, // open as a reader 
                                        Write            = HDBOMODE.HDBOWRITER, // open as a writer 
                                        Create           = HDBOMODE.HDBOCREAT,  // writer creating 
                                        Truncate         = HDBOMODE.HDBOTRUNC,  // writer truncating 
                                        DontLock         = HDBOMODE.HDBONOLCK,  // open without locking 
                                        LockNonBlocking  = HDBOMODE.HDBOLCKNB,  // lock without blocking 
                                        SyncAlways       = HDBOMODE.HDBOTSYNC,  // synchronize every transaction
                                        
                                        WriteCreate      = Write | Create,
                                        ReadOnly         = Read  | DontLock,
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
        Trace.formatln(typeof (this).stringof ~ " created").flush();
        
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

    private ~this ( )
    {
        if (!deleted)
        {
            tchdbdel(this.db);
            Trace.formatln(typeof (this).stringof ~ " deleted").flush();
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
    
    
    
    /***************************************************************************
    
        Open Database for reading/writing, create if necessary

        dbfile = specifies the database  file name
  
     **************************************************************************/    
    
    public void open ( char[] dbfile )
    {   
        tchdbtune(this.db, this.tune_bnum, this.tune_apow, this.tune_fpow, this.tune_opts);
        
        return this.openNonBlocking(dbfile, OpenStyle.WriteCreate);
    }
    
    public void openNonBlocking ( char[] dbfile, OpenStyle style )
    {
        return this.open(dbfile, style | OpenStyle.LockNonBlocking);
    }
    
    public void open ( char[] dbfile, OpenStyle style )
    {
        this.tokyoAssert(tchdbopen(this.db, this.toCstring(dbfile).ptr, style), "Open error");
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
        this.tchPut(key, value, this.async? &tchdbputasync : &tchdbput, "tchdbput");
    }
    
    public alias put opIndexAssign;
    
    
    
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
        this.tchPut(key, value, &tchdbputkeep, "tchdbputkeep", [TCHERRCODE.TCEKEEP]);
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
        this.tchPut(key, value, &tchdbputcat, "tchdbputcat");
    }
    
    
    
    /**************************************************************************
    
        Get Value of Key without heap activity using free
    
        Params:
            key = hash key
            value = return buffer for value
            
        Returns:
            true if key found, otherwise false
            
    ***************************************************************************/
    
    
    public bool get_alt ( char[] key, out char[] value )
    {
        int length;
        
        void* cvalue = tchdbget(this.db, key.ptr, key.length, &length);
        
        if (cvalue)
        {
            value = (cast (char*) cvalue)[0 .. length].dup;
            
            free(cvalue);  														// allocated by tchdbget()
            
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
            scope (exit) free(cvalue);  										// allocated by tchdbget()
            
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

    public bool get ( char[] key, out char[] value )
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
    
        Tells whether an item exists
        
         Params:
            key = item key
        
        Returns:
             true if item exists or false itherwise
    
    ***************************************************************************/

    public bool exists ( char[] key )
    {
        return (tchdbvsiz(this.db, key.ptr, key.length) >= 0);
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
        
        @see reference
        
        http://torum.net/2009/10/iterating-tokyo-cabinet-in-parallel/
        http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/
        
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
            key             = key of item to put
            value           = item value
            put_func        = Tokyo Cabinet put function
            description     = description string for error messages
            ignore_errcodes = do not throw an exception on these error codes
        
    ***************************************************************************/
   
    private void tchPut ( char[] key, char[] value, TchPutFunc put_func,
                          char[] description, TCHERRCODE[] ignore_errcodes = [] )
    in
    {
        assert (key,   "Error on " ~ description ~ ": null key");
        assert (value, "Error on " ~ description ~ ": null value");
    }
    body
    {
        this.tokyoAssert(put_func(this.db, key.ptr, key.length, value.ptr, value.length),
                         ignore_errcodes, "Error on " ~ description);
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
    
        If p is null, retrieves the current Tokyo Cabinet error code and
        throws an exception (even if the error code equals TCESUCCESS).
        
        Params:
            p       = not null assertion pointer
            context = error context description string for message
        
    ***************************************************************************/
    
    private void tokyoAssert ( void* p, char[] context = "Error" )
    {
        this.tokyoAssertStrict(!!p, context);
    }

    
    
    /**************************************************************************
    
        If ok == false, retrieves the current Tokyo Cabinet error code and
        throws an exception if the error code is different from TCESUCCESS.
        
        Params:
            ok      = assert condition
            context = error context description string for message
        
    ***************************************************************************/

    private void tokyoAssert ( bool ok, char[] context = "Error" )
    {
        this.tokyoAssert(ok, [], context);
    }
    
    
    
    /**************************************************************************
    
        If ok == false, retrieves the current Tokyo Cabinet error code and
        throws an exception (even if the error code equals TCESUCCESS).
        
        Params:
            ok      = assert condition
            context = error context description string for message
        
    ***************************************************************************/

    private void tokyoAssertStrict ( bool ok, char[] context = "Error" )
    {
        this.tokyoAssertStrict(ok, [], context);
    }
    
    
    
    /**************************************************************************
    
        If ok == false, retrieves the current Tokyo Cabinet error code and
        throws an exception if the error code is different from TCESUCCESS and
        all error codes in ignore_codes.
        
        Params:
            ok           = assert condition
            ignore_codes = do not throw an exception on these codes
            context      = error context description string for message
        
    ***************************************************************************/

    private void tokyoAssert ( bool ok, TCHERRCODE[] ignore_codes, char[] context = "Error" )
    {
        this.tokyoAssertStrict(ok, ignore_codes ~ TCHERRCODE.TCESUCCESS, context);
    }
    
    
    
    /**************************************************************************
    
        If ok == false, retrieves the current Tokyo Cabinet error code and
        throws an exception if the error code is different from  all error codes
        in ignore_codes (even if it equals TCESUCCESS).
        
        Params:
            ok           = assert condition
            ignore_codes = do not throw an exception on these codes
            context      = error context description string for message
        
    ***************************************************************************/

    private void tokyoAssertStrict ( bool ok, TCHERRCODE[] ignore_codes, char[] context = "Error" )
    {
        if (!ok)
        {
            TCHERRCODE errcode = tchdbecode(this.db);
            
            foreach (ignore_core; ignore_codes)
            {
                if (errcode == ignore_core) return; 
            }
            
            TokyoCabinetException(typeof (this).stringof ~ ": " ~
                                  context ~ ": " ~ this.getTokyoErrMsg(errcode));
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
