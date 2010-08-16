/*******************************************************************************

        Tokyo Cabinet In-Memory Hash Database

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        license:        BSD style: $(LICENSE)
        
        version:        June 2010: Initial release
                        
        author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt
        
*******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetM;

/*******************************************************************************

    Imports

********************************************************************************/

private     import  ocean.db.tokyocabinet.model.ITokyoCabinet: TokyoCabinetIterator;

private     import  ocean.db.tokyocabinet.c.tcmdb:
                        TCMDB,
                        tcmdbnew,   tcmdbnew2,     tcmdbvanish, tcmdbdel,
                        tcmdbput,   tcmdbputkeep,  tcmdbputcat,
                        tcmdbget,   tcmdbforeach,
                        tcmdbout,   tcmdbrnum,     tcmdbmsiz,   tcmdbvsiz;

private     import  tango.stdc.stdlib: free;

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
        
********************************************************************************/

class TokyoCabinetM
{
    
    /**************************************************************************
        
        Iterator alias definition
    
     **************************************************************************/
    
    private alias TokyoCabinetIterator!(TCMDB, tcmdbforeach) TcIterator;
    
    /**************************************************************************
    
        Destructor check if called twice

     **************************************************************************/
    
    private                 bool                    deleted = false;
    
    /**************************************************************************
        
        Tokyo cabinet database instance
    
     **************************************************************************/
    
    private                 TCMDB*                  db;
    
    
    /**************************************************************************
        
        Constructor; creates new in memory database instance   
                             
     **************************************************************************/
    
    public this ( ) 
    {
        this.db = tcmdbnew();
    }
    
    /**************************************************************************
        
        Constructor
        
        Params:
            bnum = number of buckets
                             
     **************************************************************************/
    
    public this ( uint bnum ) 
    {
        this.db = tcmdbnew2(bnum);
    }
    
    /**************************************************************************
    
        Destructor    
        
        FIXME: destructor called twice: why?
                             
     **************************************************************************/

    private ~this ( )
    {
        if (!this.deleted)
        {
            tcmdbdel(this.db);
        }
        
        this.deleted = true;
    }
    
    /**************************************************************************
        
        Invariant: called every time a public class method is called
                             
     **************************************************************************/
    
    invariant ( )
    {
        assert (this.db, typeof (this).stringof ~ ": invalid TokyoCabinet Hash core object");
    }
    
    /**************************************************************************
     
        Puts a record to database; overwrites an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void put ( char[] key, char[] value )
    {
        tcmdbput(this.db, key.ptr, key.length, value.ptr, value.length);
    }

    /**************************************************************************
    
        Puts a record to database; does not ooverwrite an existing record
       
        Params:
            key   = record key
            value = record value
            
    ***************************************************************************/
    
    public void putkeep ( char[] key, char[] value )
    {
        tcmdbputkeep(this.db, key.ptr, key.length, value.ptr, value.length);
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
        tcmdbputcat(this.db, key.ptr, key.length, value.ptr, value.length);
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
        int len;
        
        void* value_ = cast (void*) tcmdbget(this.db, key.ptr, key.length, &len); 
        
        bool found = !!value_;
        
        if (found)
        {
            value = (cast (char*) value_)[0 .. len].dup;
            
            free(value_);
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
        return (tcmdbvsiz(this.db, key.ptr, key.length) >= 0);
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
        return tcmdbout(this.db, key.ptr, key.length);
    }

    /**************************************************************************
        
        Returns the number of records
        
        Returns: 
            number of records, or zero if none
        
     ***************************************************************************/
    
    public ulong numRecords ()
    {
        return tcmdbrnum(this.db);
    }
    
    /**************************************************************************
    
        Returns the total size of the database object in bytes
        
        Returns: 
            total size of the database object in bytes
        
    ***************************************************************************/
    
    public ulong dbSize ()
    {
        return tcmdbmsiz(this.db);
    }

    /**************************************************************************
    
        Clears the database
        
    ***************************************************************************/

    public void clear ()
    {
        tcmdbvanish(this.db);
    }
    
    /**************************************************************************
    
        "foreach" iterator over key/value pairs of records in database. The
        "key" and "val" parameters of the delegate correspond to the iteration
        variables.
        
     ***************************************************************************/
    
    public int opApply ( TcIterator.KeyValIterDg delg )
    {
        int result;
        
        TcIterator.tcdbopapply(this.db, delg, result);
        
        return result;
    }

    /**************************************************************************
    
        "foreach" iterator over keys of records in database. The "key"
        parameter of the delegate corresponds to the iteration variable.
        
     ***************************************************************************/
    
    public int opApply ( TcIterator.KeyIterDg delg )
    {
        int result;
        
        TcIterator.tcdbopapply(this.db, delg, result);
        
        return result;
    }
}


/*******************************************************************************

    Unittest

********************************************************************************/

debug (OceanUnitTest)
{
    import tango.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;
    
    unittest
    {
        Trace.formatln("Running ocean.db.tokyocabinet.TokyoCabinetM unittest");
        
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
        
        /***********************************************************************
            
            Memory Test
            
         ***********************************************************************/
        
        Trace.formatln("running mem test...");
        
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
            
            Trace.formatln  ("[{}:{}-{}]\t{} adds with {}/s and {} bytes mem usage", 
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
        Trace.formatln("inserts = {}, hits = {}", inserts, hits);
        assert(inserts == hits);
        
        Trace.format  ("{}/{} gets/hits with {}/s and ", map.numRecords(), hits, map.numRecords()/w.stop);
        Trace.formatln("mem usage {} bytes", GC.stats["poolSize"]);
        
        Trace.formatln("done unittest\n");
    }
}