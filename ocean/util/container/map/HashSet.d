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

private import ocean.util.container.map.model.BucketSet;

private import ocean.util.container.map.model.Bucket;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Debug switch for verbose unittest output (uncomment if desired)

*******************************************************************************/

//debug = UnittestVerbose;



/*******************************************************************************

    HashSet class. Manages a set of hash_t's with fast lookup.

*******************************************************************************/

public class HashSet : BucketSet!(BucketElement!())
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

        Looks up key in the set.

        Params:
            key = key to look up

        Returns:
            true if found or false if not.

    ***************************************************************************/

    public bool opIn_r ( hash_t key )
    {
        Bucket.Element* element = this.getBucket(key).find(key);

        if (element)
        {
            assert (element.key == key);

            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Puts key into the set.

        Params:
            key = key to put into set

        Returns:
            true if the key was already on the set, false otherwise

    ***************************************************************************/

    public bool put ( hash_t key )
    {
        bool existed;

        this.getBucket(key).add(key, this.bucket_elements.get(), existed);

        return existed;
    }


    /***************************************************************************

        Removes key from the set.

        Params:
            key = key to remove from set

        Returns:
            true if the key was in the set, false otherwise

    ***************************************************************************/

    public bool remove ( hash_t key )
    {
        auto element = this.removeElement(key);

        if ( element )
        {
            this.bucket_elements.recycle(element);
            return true;
        }
        else
        {
            return false;
        }
    }


    /***************************************************************************

        Iterator scope class.

        The iteration is actually over a copy of the whole hashset. Thus the set
        may be modified while iterating. However, the list of iems iterated
        over is not updated to any changes made.

    ***************************************************************************/

    public scope class Iterator
    {
        public int opApply ( int delegate ( ref Bucket.Element.Key ) dg )
        {
            int r;

            scope it = this.outer.new ElementsIterator;
            foreach ( element; it )
            {
                r = dg(element.key);
                if ( r ) break;
            }

            return r;
        }
    }


    /***************************************************************************

        Read only iterator scope class.

        The read-only iterator is more efficient as it does not require the
        copy of the items being iterated, which the safe iterator performs. The
        hashset should not be modified while using this iterator.

    ***************************************************************************/

    public scope class ReadOnlyIterator
    {
        public int opApply ( int delegate ( ref Bucket.Element.Key ) dg )
        {
            int r;

            scope it = this.outer.new ReadOnlyElementsIterator;
            foreach ( element; it )
            {
                r = dg(element.key);
                if ( r ) break;
            }

            return r;
        }
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

        void printState ( )
        {
            Stdout.formatln("  ::  len={}, load={}, max_load={}, pool={} ({} busy)",
                set.length, set.load, set.max_load,
                set.bucket_elements.length, set.bucket_elements.num_busy);
        }

        bool lengthIs ( int expected )
        {
            assert(set.length == expected);

            int c;
            scope it = set.new ReadOnlyIterator;
            foreach ( k; it )
            {
                c++;
            }
            return c == expected;
        }

        void put ( hash_t key, bool should_exist )
        {
            auto len = set.length;

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
            auto len = set.length;
            auto pool_len = set.bucket_elements.length;

            assert(!!(key in set) == should_exist);

            auto e = set.remove(key);
            debug ( UnittestVerbose )
            {
                Stdout.format("remove {}: {}", key, e);
                printState();
            }

            assert(!(key in set));
            assert(lengthIs(len - (should_exist ? 1 : 0)));
            assert(pool_len == set.bucket_elements.length);
        }

        void clear ( )
        {
            auto pool_len = set.bucket_elements.length;

            set.clear();
            debug ( UnittestVerbose )
            {
                Stdout.format("clear");
                printState();
            }

            assert(lengthIs(0));

            assert(pool_len == set.bucket_elements.length);
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

