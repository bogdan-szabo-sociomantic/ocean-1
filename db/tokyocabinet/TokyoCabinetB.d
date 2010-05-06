/*******************************************************************************

    Tokyo Cabinet B+ Tree Database

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)
    
    version:        Mar 2010: Initial release
                    
    author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt
    
    Description:
    
        Very fast and lightweight database with 10K to 200K inserts per second
        based on the storage engine used.
    
    Usage:
    
        ---
        
        import ocean.db.tokyocabinet.TokyoCabinetB;
        
        auto db = new TokyoCabinetB();
        db.setTuneOpts(TokyoCabinetB.TuneOpts.HDBTLARGE);
        db.setTuneBnum(20_000_000);
        db.enableAsync();
        db.open("db.tch");
        
        db.add("foo", "bar");
        
        db.close;
        
        ---

 ******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetB;

/*******************************************************************************

    Imports

 ******************************************************************************/

protected   import 	ocean.core.Exception: TokyoCabinetException;

private     import 	ocean.db.tokyocabinet.util.TokyoCabinetCursor;
private     import  ocean.db.tokyocabinet.util.TokyoCabinetList;

private     import  ocean.db.tokyocabinet.c.tcbdb:
                        TCBDB,       BDBOPT,          BDBOMODE,      TCERRCODE,
                        tcbdbnew,    tcbdbdel,        tcbdbopen,     tcbdbclose,
                        tcbdbtune,   tcbdbsetmutex,   tcbdbsetcache, tcbdbsetxmsiz,
                        tcbdbput,    tcbdbputkeep,    tcbdbputcat,
                        tcbdbputdup, tcbdbputdupback,
                        tcbdbget3,   tcbdbget5,       tcbdbrange,    tcbdbforeach, 
                        tcbdbout,    tcbdbvsiz,       tcbdbvnum,     tcbdbrnum,
                        tcbdbfsiz,   tcbdbsync,       tcbdbecode,    tcbdberrmsg;
                        
private     import  ocean.db.tokyocabinet.model.ITokyoCabinet;

private     import  ocean.text.util.StringC;

debug private     import  tango.util.log.Trace;

/*******************************************************************************

	TokyoCabinetB class
    
*******************************************************************************/

class TokyoCabinetB : ITokyoCabinet!(TCBDB, tcbdbforeach)
{
    /***************************************************************************
        
        Tune structure
        
        Database tuning parameters
    
     **************************************************************************/ 

    struct Tune
    {
        int      leaf_members           = 128;                                  // 'lmemb' specifies the number of members in each leaf page. If it is not more than 0, the default value is specified. The default value is 128.    
        int      non_leaf_members       = 256;                                  // 'nmemb' specifies the number of members in each non-leaf page. If it is not more than 0, the default value is specified. The default value is 256.
        long     bucket_array_length    = 32749;                                // 'bnum' specifies the number of elements of the bucket array. If it is not more than 0, the default value is specified. The default value is 32749. Suggested size of the bucket array is about from 1 to 4 times of the number of all pages to be stored.
        byte     alignment_power        = 8;                                    // 'apow' specifies the size of record alignment by power of 2. If it is negative, the default value is specified. The default value is 8 standing for 2^8=256.
        byte     free_block_power       = 10;                                   // 'fpow' specifies the maximum number of elements of the free block pool by power of 2. If it is negative, the default value is specified. The default value is 10 standing for 2^10=1024.
        TuneOpts options                = TuneOpts.None;         
    }
	
    /***************************************************************************
    
        tune property
        
        Tune parameters may be arbitrarily set and get effective on open() call.
    
     **************************************************************************/ 

    public Tune tune;
    
	 /**************************************************************************
    
	    TuneOpts enumerator
	    
	    Large:      size of the database can be larger than 2GB 
	    Deflate:    each recordis compressed with deflate encoding
	    Bzip:       each record is compressed with BZIP2 encoding
	    Tcbs:       each record is compressed with TCBS encoding
	
	 **************************************************************************/
	
	enum    TuneOpts : BDBOPT
            {
                Large   = BDBOPT.BDBTLARGE, 
                Deflate = BDBOPT.BDBTDEFLATE,
                Bzip    = BDBOPT.BDBTBZIP,
                Tcbs    = BDBOPT.BDBTTCBS,
                
                None    = cast (BDBOPT) 0
            }
	
     /**************************************************************************
    
        OpenStyle enumerator
    
     **************************************************************************/

	enum    OpenStyle : BDBOMODE
            {
                Read             = BDBOMODE.BDBOREADER,     // open as a reader 
                Write            = BDBOMODE.BDBOWRITER,     // open as a writer 
                Create           = BDBOMODE.BDBOCREAT,      // writer creating 
                Truncate         = BDBOMODE.BDBOTRUNC,      // writer truncating 
                DontLock         = BDBOMODE.BDBONOLCK,      // open without locking 
                LockNonBlocking  = BDBOMODE.BDBOLCKNB,      // lock without blocking 
                SyncAlways       = BDBOMODE.BDBOTSYNC,      // synchronize every transaction
                
                WriteCreate      = Write | Create,
                ReadOnly         = Read  | DontLock,
            }
	
	
	/**************************************************************************
    
	    Destructor check if called twice
	
	 **************************************************************************/
	
    private bool            deleted         = false;
	
	
	
	/**************************************************************************
	    
	    Constructor    
	    
	    Params:
	        dbfile = path to database file (e.g. /tmp/store.tcb)
	                         
	 **************************************************************************/
	
	public this ( ) 
	{
	    // Trace.formatln(typeof (this).stringof ~ " created").flush();	    
	    this.db = tcbdbnew();
	}
    
	
	
	/**************************************************************************
    
	    Destructor    
	    
	    FIXME: destructor called twice: why?
	    
	    tcbdbdel() will close the database object if it is still open.
	                         
	 **************************************************************************/
	
	private ~this ( )
	{
	    if (!this.deleted)
	    {
	        tcbdbdel(this.db);
            
	        debug Trace.formatln(typeof (this).stringof ~ " deleted").flush();
	    }
	    
	    this.deleted = true;
	}

	
	
	/**************************************************************************
    
	    Invariant: called every time a public class method is called
	                         
	 **************************************************************************/
	
	invariant ( )
	{
	    assert (this.db, typeof (this).stringof ~ ": invalid TokyoCabinet B+ Tree core object");
	}
	
	
	
    /***************************************************************************
    
        Opens a database file for reading/writing, creates if necessary. If the
        database file is locked, an exception is thrown.
    
        Params:
            dbfile = specifies the database file name
    
     **************************************************************************/    

	public void open ( char[] dbfile )
	{   
        super.tokyoAssert(tcbdbtune(this.db, this.tune.leaf_members,
                                    this.tune.non_leaf_members,
                                    this.tune.bucket_array_length, 
                                    this.tune.alignment_power,
                                    this.tune.free_block_power,
                                    this.tune.options),
                          "error setting tune options");
	    
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
	    this.tokyoAssert(tcbdbopen(this.db, StringC.toCstring(dbfile), style), "Open error");
	}
	
	
    /**************************************************************************
    
        Closes the database

    ***************************************************************************/

    public void close ()
    {
        if (super.db)
        {
            super.tokyoAssert(tcbdbclose(super.db), "close error");
        }
    }
    
    

    /**************************************************************************
        
        Set Mutex for Threading (call before opening)
    
    ***************************************************************************/
    
    public void enableThreadSupport ()
    {
        super.tokyoAssert(tcbdbsetmutex(this.db), "error setting mutex");
    }
    
    
    /**************************************************************************
        
        Set number of elements in bucket array
        
        Set cache size of database before opening.
        
        Params:
            size = cache size in bytes
            
    ***************************************************************************/
        
    public void setCacheSize( int leaf, int non_leaf )
    {
        super.tokyoAssert(tcbdbsetcache(this.db, leaf, non_leaf), "error setting cache size");
    }
    
    
    
    /**************************************************************************
        
        Set memory size
        
        Set size of memory used by database before opening.
        
        Params:
            size = mem size in bytes
            
    ***************************************************************************/
    
    public void setMemSize( uint size )
    {
        super.tokyoAssert(tcbdbsetxmsiz(this.db, size), "error setting memory size");
    }
    
    

    /**************************************************************************
    
        Puts a record to database; overwrites an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/

    public void put ( char[] key, char[] value )
    {
        super.tcPut(key, value, &tcbdbput, "tcbdbput");
    }
    
    /**************************************************************************
    
        Puts a record to database; does not ooverwrite an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void putkeep ( char[] key, char[] value )
    {
        super.tcPut(key, value, &tcbdbputkeep, "tcbdbputkeep");
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
        super.tcPut(key, value, &tcbdbputcat, "tcbdbputcat");
    }
    
    /**************************************************************************
    
        Puts a record to database allowing duplication of keys.
       
        Params:
            key   = record key
            value = record value
            
     ***************************************************************************/
    
    public void putdup ( char[] key, char[] value )
    {
        super.tcPut(key, value, &tcbdbputdup, "tcbdbputdup");
    }
    
    /**************************************************************************
    
        Puts a record to database with backward duplication.
       
        Params:
            key   = record key
            value = record value
            
     ***************************************************************************/
    
    public void putdupback ( char[] key, char[] value )
    {
        super.tcPut(key, value, &tcbdbputdupback, "tcbdbputdupback");
    }
    
    
    
    
    /**************************************************************************
    
        Get record value
    
        Params:
            key = record key
    
        Returns
            value or empty string if record not existing
            
    ***************************************************************************/

    public bool get ( char[] key, out char[] value )
    {
        bool found;
        
        synchronized
        {
            int len;
            
            char* valuep = cast (char*) tcbdbget3(super.db, key.ptr, key.length, &len);
            
            found = !!valuep;
            
            if (found)
            {
                value = valuep[0 .. len].dup;
            }
        }
        
        return found;
    }
    
    /**************************************************************************
    
        Get list of records in a range
    
        Params:
            first         = key of first record in range
            last          = key of last record in range
            include_first = true/false: include/exclude first record
            include_last  = true/false: include/exclude last record
            max           = maximum range length; -1: no maximum
    
        Returns
            TokyoCabinetList.QuickIterator object providing 'foreach' iteration
            over the retrieved items. Additionally, that object can create a
            TokyoCabinetList instance.
            
     ***************************************************************************/
    
    public TokyoCabinetList.QuickIterator getDup ( char[] key )
    {
        return TokyoCabinetList.QuickIterator(tcbdbget5(super.db, key.ptr, key.length));
    }
    
    /**************************************************************************
    
        Get list of records in a range
    
        Params:
            first         = key of first record in range
            last          = key of last record in range
            include_first = true/false: include/exclude first record
            include_last  = true/false: include/exclude last record
            max           = maximum range length; -1: no maximum
    
        Returns
            TokyoCabinetList.QuickIterator object providing 'foreach' iteration
            over the retrieved items. Additionally, that object can create a
            TokyoCabinetList instance.
            
    ***************************************************************************/
    
    public TokyoCabinetList.QuickIterator getRange ( char[] first, char[] last,
                                                     bool include_first, bool include_last,
                                                     int max = -1 )
    {
        return TokyoCabinetList.QuickIterator(tcbdbrange(super.db, first.ptr, first.length, include_first,
                                                                   last.ptr,  last.length,  include_last, max));
    }
    
    /**************************************************************************
    
        Get list of records in a range. The first record is included and the last is
        excluded.
    
        Params:
            first = key of first record in range
            last  = key of last record in range
    
        Returns
            TcList.QuickIterator object providing 'foreach' iteration over the
            retrieved items. Additionally, that object can create a TcList
            instance.
            
    ***************************************************************************/

    public TokyoCabinetList.QuickIterator opSlice ( char[] first, char[] last )
    {
        return this.getRange(first, last, true, false);
    }
    
    /**************************************************************************
    
        Tells whether a record exists
        
         Params:
            key = record key
        
        Returns:
             true if record exists or false itherwise
    
    ***************************************************************************/
    
    public bool exists ( char[] key )
    {
        return (tcbdbvsiz(super.db, key.ptr, key.length) >= 0);
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
        return tcbdbout(super.db, key.ptr, key.length);
    }
    
    /**************************************************************************
    
        Returns the number of records of a key
        
        Params:
            key = record key
        
        Returns: 
            number of records, or zero if none
        
     ***************************************************************************/
    
    public int numRecords ( char[] key )
    {
        return tcbdbvnum(super.db, key.ptr, key.length);
    }
    
    
    /**************************************************************************
    
        Returns the number of records
        
        Returns: 
            number of records, or zero if none
        
    ***************************************************************************/
    
    public ulong numRecords ( )
    {
        return tcbdbrnum(super.db);
    }


    /**************************************************************************
        
        Returns the database file size in bytes
        
        Returns: 
            database file size in bytes, or zero if none
        
    ***************************************************************************/
    
    public ulong dbSize ( )
    {
        return tcbdbfsiz(super.db);
    }

    /**************************************************************************
    
        Creates a cursor for this instance
        
        Returns: 
            new Cursor
        
    ***************************************************************************/

    public TokyoCabinetCursor getCursor ( )
    {
        return new TokyoCabinetCursor(super.db);
    }
	
    /**************************************************************************
    
        Flushes the database content to file.
        
        Note: The database must be opened for writing.
        
    ***************************************************************************/

    public void flush ( )
    {
        super.tokyoAssert(tcbdbsync(this.db));   
    }
    

	/**************************************************************************
    
	    Retrieves the current Tokyo Cabinet error message string.
	    
	    Returns:
	        current Tokyo Cabinet error message string
	    
	***************************************************************************/
	
	protected char[] getTokyoErrMsg ( )
	{
	    return this.getTokyoErrMsg(tcbdbecode(this.db));
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
	    return StringC.toDString(tcbdberrmsg(errcode));
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
	        TCERRCODE errcode = tcbdbecode(this.db);
	        
	        foreach (ignore_core; ignore_codes)
	        {
	            if (errcode == ignore_core) return; 
	        }
	        
	        TokyoCabinetException(typeof (this).stringof ~ ": " ~
	                              context ~ ": " ~ this.getTokyoErrMsg(errcode));
	    }
	}
}
