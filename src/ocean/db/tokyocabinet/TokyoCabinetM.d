/*******************************************************************************

    Tokyo Cabinet In-Memory Hash Database

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        June 2010: Initial release

    author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt

    Notes regarding using this module in a threaded application:

    If using this module in an application running with with the basic garbage
    collector and threads, you need to wrap all access to TokyoCabinetM with a
    signal mask for SIGUSR1 and SIGUSR2. These signals are used by the garbage
    collector internally to suspend and resume running threads, and have been
    observed (in the old threaded / basic GC dht node) to conflict with the libc
    malloc() and free() behaviour.

    Signal masking can be achieved using ocean.sys.SignalMask.

*******************************************************************************/

module ocean.db.tokyocabinet.TokyoCabinetM;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.db.tokyocabinet.model.ITokyoCabinet: TokyoCabinetIterator;

import ocean.core.Array;
import ocean.core.TypeConvert;

import ocean.db.tokyocabinet.c.tcmdb :
           TCMDB,
           tcmdbnew, tcmdbnew2, tcmdbvanish, tcmdbdel,
           tcmdbput, tcmdbputkeep, tcmdbputcat,
           tcmdbget, tcmdbforeach,
           tcmdbout, tcmdbrnum, tcmdbmsiz, tcmdbvsiz,
           tcmdbiterinit, tcmdbiterinit2, tcmdbiternext;

import tango.stdc.stdlib : free;


/*******************************************************************************

    TokyoCabinetM

    Very fast and lightweight database with 10K to 200K inserts per second.

    Usage Example: pushing item to db

    ---

        import ocean.db.tokyocabinet.TokyoCabinetM;

        auto db = new TokyoCabinetM;

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
        tcmdbput(this.db, key.ptr, castFrom!(size_t).to!(int)(key.length),
            value.ptr, castFrom!(size_t).to!(int)(value.length));
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
        tcmdbputkeep(this.db, key.ptr, castFrom!(size_t).to!(int)(key.length),
            value.ptr, castFrom!(size_t).to!(int)(value.length));
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
        tcmdbputcat(this.db, key.ptr, castFrom!(size_t).to!(int)(key.length),
            value.ptr, castFrom!(size_t).to!(int)(value.length));
    }

    /**************************************************************************

        Get record value

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

        return this.get(key, ( char[] v )
        {
            value.copy(v);
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

    public bool get ( char[] key, void delegate ( char[] value ) value_dg )
    in
    {
        this.assertDb();
        assert(value_dg);
    }
    body
    {
        int len;

        void* value_;

        value_ = cast(void*)tcmdbget(this.db, key.ptr,
            castFrom!(size_t).to!(int)(key.length), &len);

        bool found = !!value_;

        if (found)
        {
            value_dg((cast(char*)value_)[0..len]);

            free(value_);
        }

        return found;
    }

    /**************************************************************************

        Gets the key of first record in the database. (The database's internal
        iteration position is reset to the first record.)

        Note that the getFirstKey() and getNextKey() methods are synchronized on
        this instance of the class, ensuring that only one caller at a time can
        invoke either of those methods. This is required for safety in threaded
        applications, as the methods rely on calling tcmdbiterinit2 directly
        followed by tcmdbiternext (in the iterateNextKey() method).

        Params:
            key   = record key output

        Returns
            true on success or false if record not existing

    ***************************************************************************/

    public bool getFirstKey ( ref char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        synchronized ( this )
        {
            tcmdbiterinit(this.db);
            return this.iterateNextKey(key);
        }
    }

    /**************************************************************************

        Iterates from the given key, getting the key of next record in the
        database.

        Note that the getFirstKey() and getNextKey() methods are synchronized on
        this instance of the class, ensuring that only one caller at a time can
        invoke either of those methods. This is required for safety in threaded
        applications, as the methods rely on calling tcmdbiterinit2 directly
        followed by tcmdbiternext (in the iterateNextKey() method).

        Params:
            last_key = key to iterate from
            key      = record key output

        Returns
            true on success or false if record not existing

    ***************************************************************************/

    public bool getNextKey ( char[] last_key, ref char[] key )
    in
    {
        this.assertDb();
    }
    body
    {
        synchronized ( this )
        {
            key.length = 0;

            if ( exists(last_key) )
            {
                tcmdbiterinit2(this.db, last_key.ptr,
                    castFrom!(size_t).to!(int)(last_key.length));

                if ( !this.iterateNextKey(key) )
                {
                    return false;
                }
                return this.iterateNextKey(key);
            }
            else
            {
                return false;
            }
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

        size = tcmdbvsiz(this.db, key.ptr, castFrom!(size_t).to!(int)(key.length));

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

        ok = tcmdbout(this.db, key.ptr, castFrom!(size_t).to!(int)(key.length));

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

        num = tcmdbrnum(this.db);

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

        size = tcmdbmsiz(this.db);

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
        tcmdbvanish(this.db);
    }


    /**************************************************************************

        opApply delegate. If the delegate returns <> 0, the iteration will be
        aborted.

    ***************************************************************************/

    public alias int delegate ( ref char[] key, ref char[] value ) IterDg;


    /**************************************************************************

        Context for db iteration (just stores a user-provided delegate)

    ***************************************************************************/

    private struct IterContext
    {
        /**********************************************************************

            User-provided opApply delegate to receive each record's key and
            value

        ***********************************************************************/

        IterDg dg;


        /**********************************************************************

            Return value of last call of the delegate. Required by opApply.

        ***********************************************************************/

        int ret;
    }


    /**************************************************************************

        opApply over all records in the database. Note that this iteration is
        non-interruptible and should only be used in cases where you are certain
        that no other iterations will interfere with it.

        Params:
            dg = iteration dg

        Returns:
            return value of final delegate call (0 if iteration ended, non-0 if
            it was aborted)

    ***************************************************************************/

    public int opApply ( IterDg dg )
    in
    {
        this.assertDb();
    }
    body
    {
        IterContext context;
        context.dg = dg;

        tcmdbforeach(this.db, &db_iter, cast(void*)&context);

        return context.ret;
    }


    /**************************************************************************

        TokyoCabinet-compatible iteration function. The opaque void* (the last
        parameter) contains the iteration context (see iterate(), above), which
        in turn contains the user-provided iteration delegate.

        Params:
            key_ptr = pointer to buffer containing record key
            key_len = length of buffer containing record key
            val_ptr = pointer to buffer containing record value
            val_len = length of buffer containing record value
            context_ = opaque context pointer (set in opApply(), above)

        Returns:
            true to continue iterating, false to break

    ***************************************************************************/

    extern ( C ) private static bool db_iter ( void* key_ptr, int key_len,
        void* val_ptr, int val_len, void* context_ )
    {
        auto key = (cast(char*)key_ptr)[0..key_len];
        auto val = (cast(char*)val_ptr)[0..val_len];
        auto context = cast(IterContext*)context_;

        context.ret = context.dg(key, val);
        return context.ret == 0;
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

        key_ = cast(void*)tcmdbiternext(this.db, &len);

        bool found = !!key_;

        if (found)
        {
            key.copy((cast(char*)key_)[0 .. len]);

            free(key_);
        }

        return found;
    }

    /**************************************************************************

        Asserts that the tokyocabinet database object has been initialised.

        FIXME: this used to be a class invariant, but had to be replaced with an
        in contract in all methods due to a compiler bug on linux for classes
        with invariants and synchronized methods. See:

        http://d.puremagic.com/issues/show_bug.cgi?id=235#c2

        (Now synchronized statements have been removed this can be reverted.)

    ***************************************************************************/

    private void assertDb ( )
    {
        assert(this.db, typeof (this).stringof ~ ": invalid TokyoCabinet Hash core object");
    }
}


/*******************************************************************************

    Unittests

*******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;
}

version (UnitTestVerbose) import ocean.io.Stdout : Stderr;

/*******************************************************************************

    Basic unittest -- tests get, put, exists, remove

*******************************************************************************/

unittest
{
    version ( UnitTestVerbose ) Stderr.formatln("Running ocean.db.tokyocabinet.TokyoCabinetM unittest");

    const uint iterations  = 5;
    const uint inserts     = 1_000_000;
    const uint num_threads = 1;

    /***********************************************************************

        ArrayMapKV Assertion Test

     ***********************************************************************/

    StopWatch   w;

    scope value = new char[256];

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


/*******************************************************************************

    Iteration unittest

*******************************************************************************/

unittest
{
    const uint count = 10_000;

    scope db = new TokyoCabinetM;

    // Add some values to the db
    {
        char[512] value = void;
        char[8] key;
        const ulong step = ulong.max / count;
        for ( ulong i = 0; ulong.max - i >= step; i += step )
        {
            *(cast(ulong*)key.ptr) = i;
            db.put(key, value);
        }
    }

    // Test the interruptible iterator
    char[][] keys;
    {
        char[] key;
        bool more = db.getFirstKey(key);
        while ( more )
        {
            keys ~= key.dup;
            more = db.getNextKey(key, key);
        }

        test!("==")(keys.length, count);
    }

    // Test the non-interruptible iterator
    char[][] keys2;
    {
        foreach ( char[] key, char[] val; db )
        {
            keys2 ~= key.dup;
        }
        test!("==")(keys2.length, count);
    }

    // Check that both iterations returned the same set of keys
    test!("==")(keys.length, keys2.length);
    keys.sort;
    keys2.sort;

    foreach ( i, k; keys )
    {
        test!("==")(k, keys2[i]);
    }
}


/*******************************************************************************

    Performance test

*******************************************************************************/

debug (OceanPerformanceTest)
{
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    import tango.util.container.HashMap;

    unittest
    {
        /***********************************************************************

            Memory Test

         ***********************************************************************/

        version ( UnitTestVerbose ) Stderr.formatln("running mem test...");

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

            version ( UnitTestVerbose ) Stderr.formatln  ("[{}:{}-{}]\t{} adds with {}/s and {} bytes mem usage",
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
        version ( UnitTestVerbose ) Stderr.formatln("inserts = {}, hits = {}", inserts, hits);
        assert(inserts == hits);

        version ( UnitTestVerbose )
        {
            Stderr.format  ("{}/{} gets/hits with {}/s and ", map.numRecords(), hits, map.numRecords()/w.stop);
            Stderr.formatln("mem usage {} bytes", GC.stats["poolSize"]);
            Stderr.formatln("done unittest\n");
        }
    }
}

