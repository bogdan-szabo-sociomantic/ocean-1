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
        
        scope db = new TokyoCabinetB;
        db.tune.opts |= TokyoCabinetH.TuneOpts.Large;
        db.setTuneBnum(20_000_000);
        db.open("db.tcb");
        
        db.put("foo", "bar");
        
        db.close();
        
        ---

 ******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetB;

/*******************************************************************************

    Imports

 ******************************************************************************/

private     import  ocean.core.Exception: TokyoCabinetException;

private     import  ocean.db.tokyocabinet.util.TokyoCabinetCursor;
private     import  ocean.db.tokyocabinet.util.TokyoCabinetList;
private     import  ocean.db.tokyocabinet.util.TokyoCabinetExtString;

private     import  ocean.db.tokyocabinet.c.tcbdb:
                        TCBDB,       BDBOPT,          BDBOMODE,
                        tcbdbnew,    tcbdbdel,        tcbdbopen,     tcbdbclose,
                        tcbdbtune,   tcbdbsetmutex,   tcbdbsetcache, tcbdbsetxmsiz,
                        tcbdbput,    tcbdbputkeep,    tcbdbputcat,
                        tcbdbputdup, tcbdbputdupback,
                        tcbdbget3,   tcbdbget5,       tcbdbrange,    tcbdbforeach, 
                        tcbdbout,    tcbdbvsiz,       tcbdbvnum,     tcbdbrnum,
                        tcbdbfsiz,   tcbdbsync,       tcbdbecode,    tcbdberrmsg;
                        
private     import  ocean.db.tokyocabinet.c.tcutil: TCERRCODE;

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
        static const struct Default
        {
            static const:
                
            int      lmemb = 128;    
            int      nmemb = 256;
            long     bnum  = 32749;
            byte     apow  = 8;
            byte     fpow  = 10;
            TuneOpts opts  = TuneOpts.None;         
        }
        
        int      lmemb = Default.lmemb;                                         // 'lmemb' specifies the number of members in each leaf page. If it is not more than 0, the default value is specified. The default value is 128.    
        int      nmemb = Default.nmemb;                                         // 'nmemb' specifies the number of members in each non-leaf page. If it is not more than 0, the default value is specified. The default value is 256.
        long     bnum  = Default.bnum;                                          // 'bnum' specifies the number of elements of the bucket array. If it is not more than 0, the default value is specified. The default value is 32749. Suggested size of the bucket array is about from 1 to 4 times of the number of all pages to be stored.
        byte     apow  = Default.apow;                                          // 'apow' specifies the size of record alignment by power of 2. If it is negative, the default value is specified. The default value is 8 standing for 2^8=256.
        byte     fpow  = Default.fpow;                                          // 'fpow' specifies the maximum number of elements of the free block pool by power of 2. If it is negative, the default value is specified. The default value is 10 standing for 2^10=1024.
        TuneOpts opts  = Default.opts;         
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
    
        Cursor instance for getFirst()/getLast()
    
     **************************************************************************/
    
    private TokyoCabinetCursor cursor;

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
        super.db = tcbdbnew();
        
        this.cursor = new TokyoCabinetCursor(super.db);
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
            delete this.cursor;
            
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
        super.tokyoAssert(tcbdbtune(this.db, this.tune.lmemb, this.tune.nmemb,
                                             this.tune.bnum, 
                                             this.tune.apow,  this.tune.fpow,
                                             this.tune.opts),
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
            key   = record key
            value = record value output
    
        Returns
            true on success or false if record not existing
            
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
    
        Get list of records in a range. Note that the list of record keys in
        range is built before this method returns and iteration starts.
    
        Params:
            first         = key of first record in range
            last          = key of last record in range
            include_first = true/false: include/exclude first record
            include_last  = true/false: include/exclude last record
            max           = maximum range length; -1: no maximum
    
        Returns
            TokyoCabinetList.QuickIterator object providing 'foreach' iteration
            over the retrieved records. Additionally, that object can create a
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
    
        Get 'foreach'/'foreach_reverse' iterator over records in range.
        (The records are retrieved during iteration, not before.)
    
        Params:
            first         = key of first record in range
            last          = key of last record in range
            include_first = true/false: include/exclude first record
            include_last  = true/false: include/exclude last record
    
        Returns
            RangeIterator object providing 'foreach'/'foreach_reverse'
            iteration, retrieving one record per iteration cycle.
            
    ***************************************************************************/

    public RangeIterator getRangeAlt ( char[] first, char[] last,
                                       bool include_first, bool include_last )
    {
        return RangeIterator(this, first, last, include_first, include_last);
    }
    
    /**************************************************************************
    
        Get 'foreach'/'foreach_reverse' iterator over records in range,
        including the first and excluding the last key.
        (The records are retrieved during iteration, not before.)
    
        Params:
            first         = key of first record in range
            last          = key of last record in range
    
        Returns
            RangeIterator object providing 'foreach'/'foreach_reverse'
            iteration, retrieving one record per iteration cycle.
            
     **************************************************************************/
    
    public RangeIterator getRangeAlt ( char[] first, char[] last )
    {
        return RangeIterator(this, first, last);
    }
    
    /**************************************************************************
    
        Gets the record with the first key according to the key order.
        
        Params:
            key   = last key according to key order
            value = record value corresponding to key

     **************************************************************************/

    public void getFirst ( out char[] key, out char[] value )
    {
        this.cursor.selectStart().get(key, value);
    }
    
    /**************************************************************************
    
        Gets the record with the last key according to the key order.
        
        Params:
            key   = last key according to key order
            value = record value corresponding to key
    
     **************************************************************************/

    public void getLast ( out char[] key, out char[] value )
    {
        this.cursor.selectEnd().get(key, value);
    }
    
    /**************************************************************************
    
        Gets the first key according to the key order.
        
        Params:
            key = last key according to key order
    
     **************************************************************************/

    public void getFirst ( out char[] key )
    {
        this.cursor.selectStart().get(key);
    }
    
    /**************************************************************************
    
        Gets the last key according to the key order.
        
        Params:
            key = last key according to key order
    
     **************************************************************************/

    public void getLast ( out char[] key )
    {
        this.cursor.selectEnd().get(key);
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
        return tcbdbvsiz(super.db, key.ptr, key.length) >= 0;
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
    
        Compares two keys using comparison function currently used for the
        B+tree. By default that is Tokyo Cabinet's built-in lexical order
        comparison function, referred to as "tccmplexical".
        
        Params:
            key1 = key to compare
            key2 = reference key
            
        Returns:
            A positive value for key1 > key2, a negative value for key1 < key2,
            or 0 for key1 == key2.
        
    ***************************************************************************/

    public int compareKeys ( char[] key1, char[] key2 )
    {
        // int function (char* aptr, int asiz, char* bptr, int bsiz, void* op) TCCMP;
        
        assert (!!this.db.cmp, typeof (this).stringof ~ ": no comparison function");
        
        return this.db.cmp(key1.ptr, key1.length, key2.ptr, key2.length, this.db.cmpop);
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
    
    /**************************************************************************
    
        Range iterator for TokyoCabinetB
        
    ***************************************************************************/

    struct RangeIterator
    {
        /**********************************************************************
        
            TokyoCabinetB instance
            
         **********************************************************************/

        private TokyoCabinetB      tokyo;
        
        /**********************************************************************
        
            First and last key of iteration range; may be changed at any time
            
         **********************************************************************/

        char[]              first;
        char[]              last;
        
        /**********************************************************************
        
            Inclusion flags for first and last record in range.
            May be changed at any time
            
         **********************************************************************/

        bool                include_first   = true;
        bool                include_last    = false;
        
        /**********************************************************************
        
            "Not found" indicator; if true, iteration has been halted because
            a Tokyo Cabinet cursor method reported that a key was not found.
            
         **********************************************************************/

        bool                not_found       = false;
        
        /**********************************************************************
        
            'foreach' iterator of key/value pairs in range
            
         **********************************************************************/
        
        int opApply ( int delegate ( ref char[] key, ref char[] val ) dg )
        {
            int result = 0;
            
            char[] key = this.first;
            char[] val;
            
            this.sortRangeKeys(false);
            
            try
            {
                scope cursor = this.tokyo.getCursor().select(this.first);
                
                if (!include_first)
                {
                    cursor.next();
                }
                
                cursor.get(key, val);
                
                while (!result && this.tokyo.compareKeys(key, this.last) < 0)
                {
                    result = dg(key, val);
                    
                    cursor.next().get(key, val);
                }
                
                if (include_last && !result)
                {
                    result = dg(key, val);
                }
            }
            catch (TokyoCabinetException e)
            {
                this.not_found = true;
                
                debug Trace.formatln(e.msg);
            }
            
            return result;
        }
        
        /**********************************************************************
        
            'foreach_reverse' iterator of key/value pairs in range
            
         **********************************************************************/

        int opApply_reverse ( int delegate ( ref char[] key, ref char[] val ) dg )
        {
            int result = 0;
            
            char[] key = this.first;
            char[] val;
            
            this.sortRangeKeys(true);
            
            try
            {
                scope cursor = this.tokyo.getCursor().select(this.last);
                
                if (!include_first)
                {
                    cursor.prev();
                }
                
                cursor.get(key, val);
                
                do
                {
                    result = dg(key, val);
                    
                    cursor.prev().get(key, val);
                }
                while (!result && this.tokyo.compareKeys(key, this.first) > 0)
                
                if (include_first && !result)
                {
                    result = dg(key, val);
                }
            }
            catch (TokyoCabinetException e)
            {
                this.not_found = true;
                
                debug Trace.formatln(e.msg);
            }
            
            return result;
        }
        
        /**********************************************************************
        
            Sorts the range keys this.first/this.last.
            
            Params:
                descending = true: greater key first; false: lesser key first
            
         **********************************************************************/

        private void sortRangeKeys ( bool descending )
        {
            if ((this.tokyo.compareKeys(this.first, this.last) > 0) ^ descending)
            {
                char[] tmp = this.first;
                
                this.first = this.last;
                this.last  = tmp;
            }
        }
        
    } // RangeIterator
    
    /+
    void testCmp ( )
    {
        Ctime.timeval tv;
        Ctime.gettimeofday(&tv, null);
        Cstdlib.srand48(tv.tv_usec);
        
        //char[8] hex1, hex2;
        
        UnixTime.HexTime hext;
        
        UnixTime.HexTime hext_ref;
        
        auto t_ref = UnixTime.fromDateTime(hext_ref, 2000, 1, 15, 14, 23, 51); 
        
        /*
        for (int day = 1; day <= 31; day++)
        for (int hou = 0; hou < 24; hou++) for (int min = 0; min < 60; min++) for (int sec = 0; sec < 60; sec++) 
        {
            
            auto t = UnixTime.fromDateTime(hext, 2000, 1, day, hou, min, sec);
            printf("%10d %c%c %10d\n", t, bc(t - t_ref), bc(this.compareKeys(hext, hext_ref)), t_ref);
        }
        */
        
        const int[12] mdays = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        
        for (int yea = 1970; yea <= 2030; yea++) for (int mon = 1; mon <= 12; mon++) for (int day = 1; day <= mdays[mon - 1]; day++)
        {
            int hou =  random(0, 24),
                min = random(0, 60),
                sec = random(0, 60);
            
            //printf("%4d-%2d-%2d %2d:%2d:%2d\n", yea, mon, day, hou, min, sec);
            
            auto t = UnixTime.fromDateTime(hext, yea, mon, day, hou, min, sec);
            printf("%04d-%02d-%02d %02d:%02d:%02d %10d %c%c %10d\n", yea, mon, day, hou, min, sec, t, bc(t - t_ref), bc(this.compareKeys(hext, hext_ref)), t_ref);
        }
        
        
        fflush(stdout);
        
    }
    
    private static char bc ( int i )
    {
        return i? ((i > 0)? '>' : '<') : '=';
    }
    
    private static int random ( int mini, int maxi )
    {
        return cast (int) (Cstdlib.drand48() * (maxi - mini)) + mini;
    }
    
    /*
    private static void intToHex ( size_t n, char[] hex_str )
    {
        foreach_reverse (ref c; hex_str)
        {
            c = "0123456789abcdef"[n & 0xF];
            n >>= 4;
        }
    }
    */
    +/
}

/*
//required for testCmp()

private import Cstdlib = tango.stdc.posix.stdlib:   srand48, drand48;
private import Ctime   = tango.stdc.posix.sys.time: timeval, gettimeofday;

private import tango.stdc.stdio: printf, fflush, stdout;
private import ocean.db.tokyocabinet.UnixTime;
*/
