/*******************************************************************************

    Tokyo Cabinet In-Memory Hash Database

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        June 2010: Initial release

    author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt

    Note: All calls to tokyocabinet functions, as well as calls to free(), are
    wrapped with a signal mask, preventing SIGUSR1 & SIGUSR2 from being fired
    while these functions are exectuing. These signals are used by the garbage
    collector to suspend and resume running threads, but have been observed (in
    the dht node) to conflict with the libc malloc() and free() behaviour.

    The masking code is enabled with the build flag: -version=GCSignalProtection

    FIXME: the signal masking is a quick fix, and should really be dealt with in
    the garbage collector by finding a way to not use signals.

*******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetM;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.db.tokyocabinet.model.ITokyoCabinet: TokyoCabinetIterator;

private import ocean.core.Array;
private import ocean.core.Memory;

private import ocean.db.tokyocabinet.c.tcmdb :
                        TCMDB,
                        tcmdbnew, tcmdbnew2, tcmdbvanish, tcmdbdel,
                        tcmdbput, tcmdbputkeep, tcmdbputcat,
                        tcmdbget, tcmdbforeach,
                        tcmdbout, tcmdbrnum, tcmdbmsiz, tcmdbvsiz,
                        tcmdbiterinit, tcmdbiterinit2, tcmdbiternext;

private import tango.stdc.stdlib : free;

debug private import ocean.util.log.Trace;

/*******************************************************************************

    TokyoCabinetM
    
    Very fast and lightweight database with 10K to 200K inserts per second.
    
    Usage Example: pushing item to db
    ---
    
    import ocean.db.tokyocabinet.TokyoCabinetM;
    
    scope db = new TokyoCabinetM;
    
    db.put("foo", "bar");
    
    db.close();
    
    ---
        
*******************************************************************************/

public class TokyoCabinetM
{
    
    /**************************************************************************
        
        Iterator alias definition
    
     **************************************************************************/
    
    private alias TokyoCabinetIterator!(TCMDB, tcmdbforeach) TcIterator;
    
    /**************************************************************************
    
        Destructor check if called twice

     **************************************************************************/
    
    private bool deleted = false;
    
    /**************************************************************************
        
        Tokyo cabinet database instance
    
     **************************************************************************/
    
    private TCMDB* db;
    
    
    /**************************************************************************
        
        Constructor; creates new in memory database instance   
                             
     **************************************************************************/
    
    public this ( ) 
    {
        gcSafe({
            this.db = tcmdbnew();
        });
    }
    
    /**************************************************************************
        
        Constructor
        
        Params:
            bnum = number of buckets
                             
     **************************************************************************/
    
    public this ( uint bnum ) 
    {
        gcSafe({
            this.db = tcmdbnew2(bnum);
        });
    }
    
    /**************************************************************************
    
        Destructor    
        
        FIXME: destructor called twice: why?
                             
     **************************************************************************/

    private ~this ( )
    {
        if (!this.deleted)
        {
            gcSafe({
                tcmdbdel(this.db);
            });
        }
        
        this.deleted = true;
    }
    
    /**************************************************************************
     
        Puts a record to database; overwrites an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void put ( char[] key, char[] value )
    in
    {
        this.assertDb();
    }
    body
    {
        gcSafe({
            tcmdbput(this.db, key.ptr, key.length, value.ptr, value.length);
        });
    }

    /**************************************************************************
    
        Puts a record to database; does not ooverwrite an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void putkeep ( char[] key, char[] value )
    in
    {
        this.assertDb();
    }
    body
    {
        gcSafe({
            tcmdbputkeep(this.db, key.ptr, key.length, value.ptr, value.length);
        });
    }
    
    /**************************************************************************
        
        Attaches/Concenates value to database record; creates a record if not
        existing
        
        Params:
            key   = record key
            value = value to concenate to record
            
    ***************************************************************************/
    
    public void putcat ( char[] key, char[] value )
    in
    {
        this.assertDb();
    }
    body
    {
        gcSafe({
            tcmdbputcat(this.db, key.ptr, key.length, value.ptr, value.length);
        });
    }
    
    /**************************************************************************
    
        Get record value without intermediate value buffer
    
        Params:
            key   = record key
            value = record value output
    
        Returns:
            true on success or false if record not existing

    ***************************************************************************/

    public bool get ( char[] key, ref char[] value )
    in
    {
        this.assertDb();
    }
    body
    {
        value.length = 0;

        int len;

        void* value_;

        gcSafe({
            value_ = cast(void*)tcmdbget(this.db, key.ptr, key.length, &len);
        });

        bool found = !!value_;
        
        if (found)
        {
            value.copy((cast(char*) value_)[0 .. len]);

            gcSafe({
                free(value_);
            });
        }
        
        return found;
    }
    
    /**************************************************************************
    
        Gets the key of first record in the database. (The database's internal
        iteration position is reset to the first record.)
    
        Note: this method is synchronized as it relies on calling tcmdbiterinit2
        directly followed by tcmdbiternext.

        Params:
            key   = record key output
    
        Returns
            true on success or false if record not existing

    ***************************************************************************/

    synchronized public bool getFirstKey ( ref char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        gcSafe({
            tcmdbiterinit(this.db);
        });
        return iterateNextKey(key);
    }

    /**************************************************************************

        Iterates from the given key, getting the key of next record in the
        database.

        Note: this method is synchronized as it relies on calling tcmdbiterinit2
        directly followed by tcmdbiternext.

        Params:
            last_key = key to iterate from
            key      = record key output

        Returns
            true on success or false if record not existing

    ***************************************************************************/

    synchronized public bool getNextKey ( char[] last_key, ref char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        key.length = 0;

        if ( exists(last_key) )
        {
            gcSafe({
                tcmdbiterinit2(this.db, last_key.ptr, last_key.length);
            });

            if ( !iterateNextKey(key) )
            {
                return false;
            }
            return iterateNextKey(key);
        }
        else
        {
            return false;
        }
    }

    /**************************************************************************
    
        Tells whether a record exists
        
         Params:
            key = record key
        
        Returns:
             true if record exists or false otherwise
    
    ***************************************************************************/

    public bool exists ( char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        int size;

        gcSafe({
            size = tcmdbvsiz(this.db, key.ptr, key.length);
        });

        return size >= 0;
    }
    
    /**************************************************************************
    
        Remove record
        
        Params:
            key = key of record to remove
        
        Returns:
            true on success or false otherwise
        
    ***************************************************************************/

    public bool remove ( char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        bool ok;

        gcSafe({
            ok = tcmdbout(this.db, key.ptr, key.length);
        });

        return ok;
    }

    /**************************************************************************
        
        Returns the number of records
        
        Returns: 
            number of records, or zero if none
        
     ***************************************************************************/
    
    public ulong numRecords ()
    in
    {
        this.assertDb();
    }
    body
    {
        ulong num;
        
        gcSafe({
            num = tcmdbrnum(this.db);
        });

        return num;
    }
    
    /**************************************************************************
    
        Returns the total size of the database object in bytes
        
        Returns: 
            total size of the database object in bytes
        
    ***************************************************************************/
    
    public ulong dbSize ()
    in
    {
        this.assertDb();
    }
    body
    {
        ulong size;

        gcSafe({
            size = tcmdbmsiz(this.db);
        });

        return size;
    }

    /**************************************************************************
    
        Clears the database
        
    ***************************************************************************/

    public void clear ()
    in
    {
        this.assertDb();
    }
    body
    {
        gcSafe({
            tcmdbvanish(this.db);
        });
    }
    
    /**************************************************************************
    
        "foreach" iterator over key/value pairs of records in database. The
        "key" and "val" parameters of the delegate correspond to the iteration
        variables.
        
        deprecated: use getFirstKey() and getNextKey() instead

     ***************************************************************************/
    
    deprecated public int opApply ( TcIterator.KeyValIterDg delg )
    in
    {
        this.assertDb();
    }
    body
    {
        int result;
        
        TcIterator.tcdbopapply(this.db, delg, result);
        
        return result;
    }

    /**************************************************************************
    
        "foreach" iterator over keys of records in database. The "key"
        parameter of the delegate corresponds to the iteration variable.
        
        deprecated: use getFirstKey() and getNextKey() instead

     ***************************************************************************/
    
    deprecated public int opApply ( TcIterator.KeyIterDg delg )
    in
    {
        this.assertDb();
    }
    body
    {
        int result;
        
        TcIterator.tcdbopapply(this.db, delg, result);
        
        return result;
    }

    /**************************************************************************

        Iterates from the current iteration position, getting the key of next
        record in the database.
    
        Params:
            key      = record key output
    
        Returns
            true on success or false if record not existing
    
    ***************************************************************************/
    
    private bool iterateNextKey ( ref char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        key.length = 0;

        int len;

        void* key_;

        gcSafe({
            key_ = cast(void*)tcmdbiternext(this.db, &len); 
        });

        bool found = !!key_;
    
        if (found)
        {
            key.copy((cast(char*)key_)[0 .. len]);
    
            gcSafe({
                free(key_);
            });
        }
    
        return found;
    }

    /**************************************************************************

        Asserts that the tokyocabinet database object has been initialised.

        FIXME: this used to be a class invariant, but had to be replaced with an
        in contract in all methods due to a compiler bug on linux for classes
        with invariants and synchronized methods. See:

        http://d.puremagic.com/issues/show_bug.cgi?id=235#c2

    ***************************************************************************/

    private void assertDb ( )
    {
        assert(this.db, typeof (this).stringof ~ ": invalid TokyoCabinet Hash core object");
    }
}


/*******************************************************************************

    Unittest

*******************************************************************************/

debug (OceanUnitTest)
{
    import ocean.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;
    
    unittest
    {
        debug ( Verbose ) Trace.formatln("Running ocean.db.tokyocabinet.TokyoCabinetM unittest");
        
        const uint iterations  = 5;
        const uint inserts     = 1_000_000;
        const uint num_threads = 1;
        
        /***********************************************************************
            
            ArrayMapKV Assertion Test
            
         ***********************************************************************/
        
        StopWatch   w;
        
        scope value = new char[0x100];
        
        scope map = new TokyoCabinetM(1_250_000);
        
        map.put("1", "1111");
        map.put("2", "2222");
        
        map.get("1", value);
        assert(value == "1111");
        
        map.get("2", value);
        assert(value == "2222");
        
        assert(map.exists("1"));
        assert(map.exists("2"));
        
        assert(map.numRecords() == 2);
        
        map.put("3", "3333");
        
        assert(map.numRecords() == 3);
        
        map.get("3", value);
        assert(value == "3333");
        
        map.remove("3");
        assert(!map.exists("3"));
        assert(map.numRecords() == 2);
    }
}

        
/*******************************************************************************

    Performance test

*******************************************************************************/

debug (OceanPerformanceTest)
{
    import ocean.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;

    unittest
    {
        /***********************************************************************
            
            Memory Test
            
         ***********************************************************************/
        
        debug ( Verbose ) Trace.formatln("running mem test...");
        
        char[] toHex ( uint n, char[8] hex )
        {
            foreach_reverse (ref c; hex)
            {
                c = "0123456789abcdef"[n & 0xF];
                
                n >>= 4;
            }
            
            return hex;
        }

        char[8] hex;
        
        for ( uint r = 1; r <= iterations; r++ )
        {
            map.clear();
            
            w.start;
            
            for ( uint i = ((inserts * r) - inserts); i < (inserts * r); i++ )
            {
                toHex(i, hex);
                
                map.put(hex, hex);
            }

            debug ( Verbose ) Trace.formatln  ("[{}:{}-{}]\t{} adds with {}/s and {} bytes mem usage", 
                    r, ((inserts * r) - inserts), (inserts * r), map.numRecords(), 
                    map.numRecords()/w.stop, GC.stats["poolSize"]);
        }
        
        w.start;
        uint hits = 0;
        uint* p;
        
        for ( uint i = ((inserts * iterations) - inserts); i < (inserts * iterations); i++ )
        {
            if ( map.exists(toHex(i, hex)) ) hits++;
        }
        debug ( Verbose ) Trace.formatln("inserts = {}, hits = {}", inserts, hits);
        assert(inserts == hits);
        
        debug ( Verbose ) Trace.format  ("{}/{} gets/hits with {}/s and ", map.numRecords(), hits, map.numRecords()/w.stop);
        debug ( Verbose ) Trace.formatln("mem usage {} bytes", GC.stats["poolSize"]);
        
        debug ( Verbose ) Trace.formatln("done unittest\n");
    }
}

