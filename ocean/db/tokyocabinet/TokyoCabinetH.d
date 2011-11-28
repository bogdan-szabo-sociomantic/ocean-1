/*******************************************************************************

        Tokyo Cabinet Hash Database

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        May 2009: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt
        
        Description:

        Very fast and lightweight database with 10K to 200K inserts per second
        based on the storage engine used.
        
        ---
        
            import ocean.db.tokyocabinet.TokyoCabinetH;
            
            auto db = new TokyoCabinetH;
            db.tune.opts |= TokyoCabinetH.TuneOpts.Large;
            db.setTuneBnum(20_000_000);
            db.enableAsync();
            db.open("db.tch");
            
            db.add("foo", "bar");
            
            db.close();
        
        ---
        
 ******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetH;


/*******************************************************************************

    Imports

 ******************************************************************************/

protected   import 	ocean.core.Exception: TokyoCabinetException;

private     import  ocean.db.tokyocabinet.model.ITokyoCabinet;

private     import  ocean.db.tokyocabinet.c.tchdb:
                        TCHDB,      HDBOPT,        HDBOMODE,
                        tchdbnew,   tchdbdel,      tchdbopen,     tchdbclose,
                        tchdbtune,  tchdbsetmutex, tchdbsetcache, tchdbsetxmsiz,
                        tchdbput,   tchdbputasync, tchdbputkeep,  tchdbputcat,
                        tchdbget,   tchdbget3,     tchdbforeach,  tchdbsync,
                        tchdbout,   tchdbrnum,     tchdbvsiz,     tchdbfsiz,
                        tchdbecode, tchdberrmsg,   tchdbpath,     tchdbvanish;

private     import ocean.db.tokyocabinet.c.tcutil: TCERRCODE;
    
private     import  ocean.text.util.StringC;


debug 
{
    private import  tango.util.log.Trace;
}


/*******************************************************************************

    TokyoCabinetH class

*******************************************************************************/

class TokyoCabinetH : ITokyoCabinet!(TCHDB, tchdbforeach)
{
    
    /**************************************************************************
    
        Tuning parameter for hash database tchdbtune
    
     **************************************************************************/ 
    
    struct Tune
    {
        static const struct Default
        {
            static const:
                
            long            bnum = 131_071;       
            byte            apow = 4;
            byte            fpow = 10;
            TuneOpts        opts = TuneOpts.Large;
        }
        
        long            bnum = Default.bnum;
        byte            apow = Default.apow;
        byte            fpow = Default.fpow;
        TuneOpts        opts = Default.opts;         
    }
    
    /***************************************************************************
    
        tune property
        
        Tune parameters may be arbitrarily set and get effective on open() call.
    
     **************************************************************************/ 

    public Tune tune;
    
    /**************************************************************************
        
        Asynchronous put request flag; Effective on put() call; 
        
		Disabled by default
    
     **************************************************************************/ 
    
    public          bool            async = false;
    
    /**************************************************************************
        
        TuneOpts enumerator
    
        Large:      size of the database can be larger than 2GB 
        Deflate:    each recordis compressed with deflate encoding
        Bzip:       each record is compressed with BZIP2 encoding
        Tcbs:       each record is compressed with TCBS encoding
    
     **************************************************************************/
    
    enum    TuneOpts : HDBOPT
            {
                Large   = HDBOPT.HDBTLARGE, 
                Deflate = HDBOPT.HDBTDEFLATE,
                Bzip    = HDBOPT.HDBTBZIP,
                Tcbs    = HDBOPT.HDBTTCBS,
                
                None    = cast (HDBOPT) 0
            }
    
    /**************************************************************************
    
        OpenStyle enumerator
    
     **************************************************************************/

    enum    OpenStyle : HDBOMODE
            {
                Read             = HDBOMODE.HDBOREADER,     // open as a reader 
                Write            = HDBOMODE.HDBOWRITER,     // open as a writer 
                Create           = HDBOMODE.HDBOCREAT,      // writer creating 
                Truncate         = HDBOMODE.HDBOTRUNC,      // writer truncating 
                DontLock         = HDBOMODE.HDBONOLCK,      // open without locking 
                LockNonBlocking  = HDBOMODE.HDBOLCKNB,      // lock without blocking 
                SyncAlways       = HDBOMODE.HDBOTSYNC,      // synchronize every transaction
                
                WriteCreate      = Write | Create,
                ReadOnly         = Read  | DontLock,
            }
    
    /**************************************************************************
    
        Destructor check if called twice

     **************************************************************************/
    
    private bool            deleted         = false;
    
    /***************************************************************************
    
    	Name of databse file, stored for outputting in error messages

    ***************************************************************************/

    protected char[] db_name;
    
    
    /**************************************************************************
        
        Constructor    
        
        Params:
            dbfile = path to database file (e.g. /tmp/store.tch)
                             
     **************************************************************************/
    
    public this ( ) 
    {
        debug Trace.formatln(typeof (this).stringof ~ " created").flush();

        super.db = tchdbnew();
    }
    
    
    
    /**************************************************************************
    
        Destructor    
        
        FIXME: destructor called twice: why?
        
        tchdbdel() will close the database object if it is still open.
                             
     **************************************************************************/

    private ~this ( )
    {
        if (!this.deleted)
        {
            tchdbdel(super.db);
            
            debug 
            {
                Trace.formatln(typeof (this).stringof ~ " deleted").flush();
            }
        }
        
        this.deleted = true;
    }
    
    
    
    /**************************************************************************
        
        Invariant: called every time a public class method is called
                             
     **************************************************************************/
    
    invariant ( )
    {
        assert (super.db, typeof (this).stringof ~ ": invalid TokyoCabinet Hash core object");
    }
    
    
    
    /***************************************************************************
    
        Opens a database file for reading/writing, creates if necessary. If the
        database file is locked, an exception is thrown.

        Params:
            dbfile = specifies the database file name
  
     **************************************************************************/

    public void open ( char[] dbfile )
    {   
        debug Trace.formatln(typeof (this).stringof ~ " opened {}", dbfile).flush();
    	this.db_name = dbfile;
        return this.openNonBlocking(dbfile, OpenStyle.WriteCreate);
    }
    
    /***************************************************************************
    
        Opens a database file. If the file is locked, an exception is thrown.
    
        Params:
            dbfile = specifies the database file name
            style  = open style (Read, Write, ReadOnly, ...)
    
     **************************************************************************/    

    public void openNonBlocking ( char[] dbfile, OpenStyle style )
    {
        return this.open(dbfile, style | OpenStyle.LockNonBlocking);
    }


    /***************************************************************************
    
        Opens a database file. If the file is locked and style is not composed
        of OpenStyle.LockNonBlocking, the method blocks until the file is
        released.
    
        Params:
            dbfile = specifies the database file name
            style  = open style (Read, Write, ReadOnly, ...)
    
     **************************************************************************/    

    public void open ( char[] dbfile, OpenStyle style )
    {
    	super.tokyoAssert(tchdbtune(super.db,
                                    this.tune.bnum,
                                    this.tune.apow, 
                                    this.tune.fpow,
                                    this.tune.opts),
                           "error setting tune options");
        
        super.tokyoAssert(tchdbopen(super.db, StringC.toCstring(dbfile), style), "Open error");
    }
    
    
    /**************************************************************************
        
        Closes the database
    
    ***************************************************************************/
    
    public void close ()
    {
    	scope ( failure )
    	{
            debug Trace.formatln(typeof (this).stringof ~ " error closing {}", this.db_name).flush();
    	}
    	scope ( success )
    	{
            debug Trace.formatln(typeof (this).stringof ~ " closed {}", this.db_name).flush();
    	}

    	if (super.db)
        {
            super.tokyoAssert(tchdbclose(super.db), "close error");
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
        super.tokyoAssert(tchdbsetmutex(super.db), "error setting mutex");
    }

    
    
    /**************************************************************************
    
        Set number of elements in bucket array 
        
        Params:
            bnum = number or initial records (init size)
            
    ***************************************************************************/
    
    public void setTuneBnum ( uint bnum = Tune.bnum.init )
    {
        this.tune.bnum = bnum;
    }
    
    
    
    /**************************************************************************
    
        Enable database tune option
        
        TuneOpts.Large:      size of the database can be larger than 2GB 
        TuneOpts.Deflate:    each recordis compressed with deflate encoding
        TuneOpts.Bzip:       each record is compressed with BZIP2 encoding
        TuneOpts.Tcbs:       each record is compressed with TCBS encoding
        
        Params:
            option = tune option
            
     ***************************************************************************/
    
    public void enableTuneOption ( TuneOpts option )
    {
        this.tune.opts |= option;
    }
    
    
    /**************************************************************************
    
        Disable database tune option
        
        TuneOpts.Large:      size of the database can be larger than 2GB 
        TuneOpts.Deflate:    each recordis compressed with deflate encoding
        TuneOpts.Bzip:       each record is compressed with BZIP2 encoding
        TuneOpts.Tcbs:       each record is compressed with TCBS encoding
        
        Params:
            option = tune option
            
    ***************************************************************************/
    
    public void disableTuneOption ( TuneOpts option )
    {
        this.tune.opts &= ~option;
    }
    
    
    
    /**************************************************************************
        
        Set cache length of database before opening.
        
        Params:
            size = cache size in bytes
            
    ***************************************************************************/
        
    public void setCacheSize( uint size )
    {
        super.tokyoAssert(tchdbsetcache(super.db, size), "error setting cache size");
    }
    
    
    
    /**************************************************************************
        
        Set memory size
        
        Set size of memory used by database before opening.
        
        Params:
            size = mem size in bytes
            
    ***************************************************************************/
    
    public void setMemSize( uint size )
    {
        super.tokyoAssert(tchdbsetxmsiz(super.db, size), "error setting memory size");
    }
    
    
    
    /**************************************************************************
     
        Puts a record to database; overwrites an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void put ( char[] key, char[] value )
    {
        super.tcPut(key, value, this.async? &tchdbputasync : &tchdbput, "tchdbput");
    }
    
    
    /**************************************************************************
    
        Puts a record to database; does not ooverwrite an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void putkeep ( char[] key, char[] value )
    {
        super.tcPut(key, value, &tchdbputkeep, "tchdbputkeep", [TCERRCODE.TCEKEEP]);
    }
    
    
    
    /**************************************************************************
        
        Attaches/Concenates value to database record; creates a record if not
        existing
        
        Params:
            key   = record key
            value = value to concenate to record
            
    ***************************************************************************/
    
    public void putcat ( char[] key, char[] value )
    {
        super.tcPut(key, value, &tchdbputcat, "tchdbputcat");
    }
    
    
    
    /**************************************************************************
    
        Get Value of Key without heap activity using free
    
        Params:
            key = hash key
            value = return buffer for value
            
        Returns:
            true if key found, otherwise false
            
    ***************************************************************************/
    
    deprecated public bool get_alt ( char[] key, out char[] value )
    {
        int length;
        
        void* cvalue = tchdbget(super.db, key.ptr, key.length, &length);
        
        if (cvalue)
        {
            value = (cast (char*) cvalue)[0 .. length].dup;
            
            free(cvalue);  														// allocated by tchdbget()
            
            return true;
        }
        
        return false;
    }
    
    
    
    /**************************************************************************
    
        Get record value
    
        Params:
            key = record key
    
        Returns
            value or empty string if item not existing
            
    ***************************************************************************/
    
    public char[] get ( char[] key )
    {
        int length;
        
        void* cvalue = tchdbget(super.db, key.ptr, key.length, &length);
        
        if (cvalue)
        {
            scope (exit) free(cvalue);  										// allocated by tchdbget()
            
            return (cast (char*) cvalue)[0 .. length].dup;
        }
        
        return "";
    }
    
    
    
    /**************************************************************************
    
        Get record value without intermediate value buffer
    
        Params:
            key   = record key
            value = record value output
    
        Returns
            true on success or false if record not existing
            
    ***************************************************************************/

    public bool get ( char[] key, ref char[] value )
    {
        value.length = 0;
        
        int length = tchdbvsiz(super.db, key.ptr, key.length);
        
        bool found = length >= 0;
        
        if (found)
        {
            value.length = length;
            
            found = (tchdbget3(super.db, key.ptr, key.length, value.ptr, length) >= 0);
            
            if (!found)
            {
                value.length = 0;
            }
        }
        
        return found;
    }
    
    
    /**************************************************************************
    
        Tells whether a record exists
        
         Params:
            key = record key
        
        Returns:
             true if record exists or false otherwise
    
    ***************************************************************************/

    public bool exists ( char[] key )
    {
        return (tchdbvsiz(super.db, key.ptr, key.length) >= 0);
    }
    
    
    
    /**************************************************************************
    
        Remove record
        
        Params:
            key = key of record to remove
        
        Returns:
            true on success or false otherwise
        
    ***************************************************************************/

    public bool remove ( char[] key )
    {
        return tchdbout(super.db, key.ptr, key.length);
    }
    
    
    /**************************************************************************
    
        Clears the database
        
        Returns:
            true on success or false otherwise
        
    ***************************************************************************/
    
    public bool clear ( )
    {
        return tchdbvanish(super.db);
    }


    /**************************************************************************
        
        Returns the number of records
        
        Returns: 
            number of records, or zero if none
        
     ***************************************************************************/
    
    public ulong numRecords ()
    {
        return tchdbrnum(super.db);
    }
    
    /**************************************************************************
        
        Returns the database file size in bytes
        
        Returns: 
            database file size in bytes, or zero if none
        
    ***************************************************************************/
    
    public ulong dbSize ()
    {
        return tchdbfsiz(super.db);
    }
    
    /**************************************************************************
    
        Flushes the database content to file.
        
        Note: The database must be opened for writing.
        
    ***************************************************************************/

    public void flush ( )
    {
        super.tokyoAssert(tchdbsync(this.db));
    }


    /**************************************************************************
    
	    Tells whether a database file is open.

	    Returns:
	    	true if a db file is open, false otherwise
	    
	***************************************************************************/

    public bool isOpen ( )
    {
    	return this.path() != "";
    }


    /**************************************************************************
    
	    Gets the path of the currently open database file.
	
	    Returns:
	    	path of open db file, or an empty string if no db file is open.
	    
	***************************************************************************/

    public char[] path ( )
    {
    	char* path = tchdbpath(super.db);
    	if ( path )
    	{
    		char* end = path;
    		while ( *end != '\0' )
    		{
    			end++;
    		}
    		return path[0..end - path];
    	}
    	return "";
    }

    /**************************************************************************
    
        Retrieves the current Tokyo Cabinet error message string.
        
        Returns:
            current Tokyo Cabinet error message string
        
    ***************************************************************************/

    protected char[] getTokyoErrMsg ( )
    {
        return this.getTokyoErrMsg(tchdbecode(super.db));
    }
    
    
    
    /**************************************************************************
    
	    Retrieves the Tokyo Cabinet error message string for errcode.
	    
	    Params:
	        errcode = Tokyo Cabinet error code
	        
	    Returns:
	        Tokyo Cabinet error message string for errcode
	    
	***************************************************************************/
    
    protected char[] getTokyoErrMsg ( TCERRCODE errcode )
	{
	    return StringC.toDString(tchdberrmsg(errcode));
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

    protected void tokyoAssertStrict ( bool ok, TCERRCODE[] ignore_codes, char[] context = "Error" )
    {
        if (!ok)
        {
            TCERRCODE errcode = tchdbecode(super.db);

            foreach (ignore_core; ignore_codes)
            {
                if (errcode == ignore_core) return; 
            }
            
            TokyoCabinetException(typeof (this).stringof ~ ": " ~
                                  context ~ ": " ~ this.getTokyoErrMsg(errcode) ~
                                  " (in database " ~ this.db_name ~ ")");
        }
    }
}
