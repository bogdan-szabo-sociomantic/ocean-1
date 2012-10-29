/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Class implementing a set of hashes. The set is built on top of an efficient
    bucket algorithm, allowing for fast look up of hashes in the set.

    Usage example:

    ---

        private import ocean.util.container.map.HashSet;

        // A set of hash_t's
        auto set = new HashSet;

        hash_t hash = 232323;

        // Add a hash
        set.put(hash));

        // Check if a hash exists in the set (null if not found)
        auto exists = hash in set;

        // Remove a hash from the set
        set.remove(hash);

        // Clear the set
        set.clear();

    ---

*******************************************************************************/

module ocean.util.container.map.HashSet;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.map.Set;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Debug switch for verbose unittest output (uncomment if desired)

*******************************************************************************/

//debug = UnittestVerbose;

debug ( UnittestVerbose )
{
    private import tango.io.Stdout;
}

/*******************************************************************************

    HashSet class. Manages a set of hash_t's with fast lookup.

*******************************************************************************/

public class HashSet : Set!(hash_t)
{
    /***************************************************************************

        Constructor, sets the number of buckets to n * load_factor

        Params:
            n = expected number of elements
            load_factor = load factor

    ***************************************************************************/

    public this ( size_t n, float load_factor = 0.75 )
    {
        super(n, load_factor);
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

        HashSet unittest.

    ***************************************************************************/

    unittest
    {
        debug ( UnittestVerbose )
        {
            Stdout.formatln("{} unittest ---------------",
                typeof(this).stringof);
            scope ( exit ) Stdout.formatln("{} unittest ---------------",
               typeof(this).stringof);
        }

        scope set = new typeof(this)(10);

        debug ( UnittestVerbose ) void printState ( )
        {
            Stdout.formatln("  ::  len={}, load={}, max_load={}, pool={} ({} busy)",
                set.length, set.load, set.max_load,
                set.bucket_elements.length, set.bucket_elements.num_busy);
        }

        bool lengthIs ( int expected )
        {
            assert(set.bucket_info.length == expected);

            int c;
            foreach ( k; set )
            {
                c++;
            }
            return c == expected;
        }

        void put ( hash_t key, bool should_exist )
        {
            auto len = set.bucket_info.length;

            assert(!!(key in set) == should_exist);

            auto e = set.put(key);
            debug ( UnittestVerbose )
            {
                Stdout.format("put {}: {}", key, e);
                printState();
            }

            assert(key in set);
            assert(lengthIs(len + (should_exist ? 0 : 1)));
        }

        void remove ( hash_t key, bool should_exist )
        {
            auto len = set.bucket_info.length;
            auto pool_len = set.bucket_info.num_buckets;

            assert(!!(key in set) == should_exist);

            auto e = set.remove(key);
            debug ( UnittestVerbose )
            {
                Stdout.format("remove {}: {}", key, e);
                printState();
            }

            assert(!(key in set));
            assert(lengthIs(len - (should_exist ? 1 : 0)));
            assert(pool_len == set.bucket_info.num_buckets);
        }

        void clear ( )
        {
            auto pool_len = set.bucket_info.num_buckets;

            set.clear();
            debug ( UnittestVerbose )
            {
                Stdout.format("clear");
                printState();
            }

            assert(lengthIs(0));

            assert(pool_len == set.bucket_info.num_buckets);
        }

        put(4711, false);   // put
        put(4711, true);    // double put
        put(23, false);     // put
        put(12, false);     // put
        remove(23, true);   // remove
        remove(23, false);  // double remove
        put(23, false);     // put
        put(23, true);      // double put

        clear();

        put(4711, false);   // put
        put(11, false);     // put
        put(11, true);      // double put
        put(12, false);     // put
        remove(23, false);  // remove
        put(23, false);     // put
        put(23, true);      // double put

        clear();
    }
}
