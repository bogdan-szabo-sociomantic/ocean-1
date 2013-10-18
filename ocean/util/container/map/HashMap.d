/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Template for a class implementing a mapping from hashes to a user-specified
    type.

    The interface of the class has been kept deliberately simple, purely
    handling the management of the mapping. The handling of the mapping values
    is left entirely up to the user -- all methods simply return a pointer to
    the mapping value which the user can do what they like with. (This is an
    intentional design decision, in order to reduce the complexity of the
    template.)

    The HashMap is designed as a replacement for ocean.core.ArrayMap. It has
    several advantages:
        1. Memory safety. As the ArrayMap's buckets are implemented as dynamic
           arrays, each bucket will theoretically grow continually in size over
           extended periods of use. Even when clear()ed, the buffers allocated
           for the buckets will not reduce in size. The HashMap, on the other
           hand, uses a pool of elements, meaning that the memory allocated for
           each bucket is truly variable.
        2. Code simplicity via removing optional advanced features such as
           thread safety and value array copying.
        3. Extensibility. Functionality is split into several modules, including
           a base class for easier reuse of components.

    Usage example with various types stored in mapping:

    ---

        private import ocean.util.container.map.HashMap;

        // Mapping from hash_t -> int
        auto map = new HashMap!(int);

        hash_t hash = 232323;

        // Add a mapping
        *(map.put(hash)) = 12;

        // Look up a mapping and obtain a pointer to the value if found or null
        // if not found;
        int* val = hash in map;

        bool exists = val !is null;

        // Remove a mapping
        map.remove(hash);

        // Clear the map
        map.clear();

        // Mapping from hash_t -> char[]
        auto map2 = new HashMap!(char[]);

        // Add a mapping
        char[]* val2 = map2.put(hash);

        (*val2).length = "hello".length;
        (*val2)[]      = "hello";

        // Mapping from hash_t -> struct
        struct MyStruct
        {
            int x;
            float y;
        }

        auto map3 = new HashMap!(MyStruct);

        // Add a mapping, put() never returns null

        with (*map3.put(hash))
        {
            x = 12;
            y = 23.23;
        }

    ---

*******************************************************************************/

module ocean.util.container.map.HashMap;

private import ocean.util.container.map.Map;

debug private import ocean.io.Stdout;


/*******************************************************************************

    Debug switch for verbose unittest output (uncomment if desired)

*******************************************************************************/

//    debug = UnittestVerbose;

debug ( UnittestVerbose )
{
    private import ocean.io.Stdout;
}

/*******************************************************************************

    HashMap class template. Manages a mapping from hash_t to the specified type.

    Template params:
        V = type to store in values of map

*******************************************************************************/

public class HashMap ( V ) : Map!(V, hash_t)
{
    /***************************************************************************

        Constructor.

        Params:
            n = expected number of elements in mapping
            load_factor = ratio of n to the number of internal buckets. The
                desired (approximate) number of elements per bucket. For
                example, 0.5 sets the number of buckets to double n; for 2 the
                number of buckets is the half of n. load_factor must be greater
                than 0. The load factor is basically a trade-off between memory
                usage (number of buckets) and search time (number of elements
                per bucket).

    ***************************************************************************/

    public this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
    }

    /***************************************************************************

        Constructor.

        Params:
            allocator = custom bucket elements allocator
            n = expected number of elements in mapping
            load_factor = ratio of n to the number of internal buckets. The
                desired (approximate) number of elements per bucket. For
                example, 0.5 sets the number of buckets to double n; for 2 the
                number of buckets is the half of n. load_factor must be greater
                than 0. The load factor is basically a trade-off between memory
                usage (number of buckets) and search time (number of elements
                per bucket).

    ***************************************************************************/

    public this ( IAllocator allocator, size_t n, float load_factor = 0.75 )
    {
        super(allocator, n, load_factor);
    }

    /***************************************************************************

        Calculates the hash value from key. Uses the identity since key is
        expected to be a suitable hash value.

        Params:
            key = key to hash

        Returns:
            the hash value that corresponds to key, which is key itself.

    ***************************************************************************/

    public hash_t toHash ( hash_t key )
    {
        return key;
    }

    /***************************************************************************

        HashMap unittest.

    ***************************************************************************/

    unittest
    {
        debug ( UnittestVerbose )
        {
            Stdout.formatln("{} unittest ---------------",
                typeof(this).stringof);
            scope ( success ) Stdout.formatln("{} unittest ---------------",
               typeof(this).stringof);
        }

        scope map = new typeof(this)(10);

        debug ( UnittestVerbose ) void printState ( )
        {
            Stdout.formatln("  ::  len={}, load={}, max_load={}",
                map.bucket_info.length, map.bucket_info.load, map.bucket_info.max_load);
        }

        bool lengthIs ( int expected )
        {
            assert(map.bucket_info.length == expected);

            int c;
            foreach ( k, v; map )
            {
                c++;
            }
            return c == expected;
        }

        void put ( hash_t key, bool should_exist )
        {
            auto len = map.bucket_info.length;

            assert(((key in map) !is null) == should_exist);

            auto e = map.put(key);

            *e = V.init;

            debug ( UnittestVerbose )
            {
                Stdout.format("put {}: {}", key, e);
                printState();
            }

            assert((key in map) !is null);

            static if (is (V U : U[]) && !is (V == V[]))
            {
                // work around DMD bug 7752

                V v_init;

                assert(*map.get(key) == v_init);
            }
            else static if ( is ( V == class ) )
            {
                assert(*map.get(key) is V.init);
            }
            else
            {
                assert(*map.get(key) == V.init, "Value does not equal previously set value");
            }

            assert(lengthIs(len + (should_exist ? 0 : 1)),
                   "Length different from foreach-counted elements!");
        }

        void remove ( hash_t key, bool should_exist )
        {
            auto len = map.bucket_info.length;
            auto pool_len = map.bucket_info.num_buckets;

            assert(((key in map) !is null) == should_exist);

            auto e = map.remove(key);
            debug ( UnittestVerbose )
            {
                Stdout.format("remove {}: {}", key, e);
                printState();
            }

            assert(!(key in map));
            assert(lengthIs(len - (should_exist ? 1 : 0)));
            assert(pool_len == map.bucket_info.num_buckets);
        }

        void clear ( )
        {
            auto pool_len = map.bucket_info.num_buckets;

            map.clear();
            debug ( UnittestVerbose )
            {
                Stdout.format("clear");
                printState();
            }

            assert(lengthIs(0));

            assert(pool_len == map.bucket_info.num_buckets);
        }

        uint[hash_t] expected_keys;

        void checkContent ( )
        {
            foreach (key, val; map)
            {
                uint* n = key in expected_keys;

                assert (n !is null);

                assert (!*n, "duplicate key");

                (*n)++;
            }

            foreach (n; expected_keys)
            {
                assert (n == 1);
            }
        }

        put(4711, false);   // put
        put(4711, true);    // double put
        put(23, false);     // put
        put(12, false);     // put

        expected_keys[4711] = 0;
        expected_keys[23]   = 0;
        expected_keys[12]   = 0;

        checkContent();

        remove(23, true);   // remove
        remove(23, false);  // double remove

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;

        expected_keys.remove(23);

        checkContent();

        put(23, false);     // put
        put(23, true);      // double put

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;
        expected_keys[23]   = 0;

        checkContent();

        clear();

        foreach (key, val; map)
        {
            assert (false);
        }

        put(4711, false);   // put
        put(11, false);     // put
        put(11, true);      // double put
        put(12, false);     // put

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;
        expected_keys[11]   = 0;
        expected_keys.remove(23);

        checkContent();

        remove(23, false);  // remove
        put(23, false);     // put
        put(23, true);      // double put

        expected_keys[4711] = 0;
        expected_keys[12]   = 0;
        expected_keys[11]   = 0;
        expected_keys[23]   = 0;

        checkContent();

        clear();

        foreach (key, val; map)
        {
            assert (false);
        }

//            foreach (i, bucket; map.buckets)
//            {
//                Stdout.formatln("Bucket {,2}: {,2} elements:", i, bucket.length);
//                foreach ( element; bucket )
//                {
//                    Stdout.formatln("  {,2}->{,2}", element.key,
//                        *(cast(V*)element.val.ptr));
//                }
//            }
    }


}
