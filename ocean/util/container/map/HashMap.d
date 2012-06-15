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

        // Check if a mapping exists (null if not found)
        auto exists = hash in map;

        // Remove a mapping
        map.remove(hash);

        // Clear the map
        map.clear();

        // Mapping from hash_t -> char[]
        auto map2 = new HashMap!(char[]);

        // Add a mapping
        map2.put(hash).copy("hello");

        // Mapping from hash_t -> struct
        struct MyStruct
        {
            int x;
            float y;
        }

        auto map3 = new HashMap!(MyStruct);

        // Add a mapping
        *(map3.put(hash)) = MyStruct(12, 23.23);

    ---

*******************************************************************************/

module ocean.util.container.map.HashMap;



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

    HashMap class template. Manages a mapping from hash_t to the specified type.

    Template params:
        V = type to store in values of map

*******************************************************************************/

public class HashMap ( V ) : BucketSet!(ValueBucketElement!(V.sizeof))
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

        In operator. Checks if a mapping exists for the given key.

        Params:
            key = key to look for

        Returns:
            pointer to the value mapped by key, if it exists. null otherwise.

    ***************************************************************************/

    public V* opIn_r ( hash_t key )
    {
        Bucket.Element* element = this.getBucket(key).find(key);

        return element ? cast(V*)element.val.ptr : null;
    }


    /***************************************************************************

        Adds or updates a mapping from the specified key.

        Params:
            key = key to add/update mapping for

        Returns:
            pointer to the value mapped to by the specified key. The caller
            should set the value as desired.

    ***************************************************************************/

    public V* put ( hash_t key )
    {
        auto bucket = this.getBucket(key);
        return cast(V*)bucket.add(key, this.bucket_elements.get()).val.ptr;
    }


    /***************************************************************************

        Removes the mapping for the specified key.

        Params:
            key = key to remove mapping for

        Returns:
            pointer to the value mapped to by the specified key

    ***************************************************************************/

    public V* remove ( hash_t key )
    {
        auto element = this.removeElement(key);

        if ( element )
        {
            this.bucket_elements.recycle(element);
            return cast(V*)element.val.ptr;
        }
        else
        {
            return null;
        }
    }


    /***************************************************************************

        Iterator scope class.

        The iteration is actually over a copy of the hashmap. Thus the mappings
        may be modified while iterating. However, the list of mappings iterated
        over is not updated to any changes made.

    ***************************************************************************/

    public scope class Iterator
    {
        public int opApply ( int delegate ( ref Bucket.Element.Key, ref V* ) dg )
        {
            int r;

            scope it = this.outer.new ElementsIterator;
            foreach ( element; it )
            {
                auto value = cast(V*)element.val.ptr;
                r = dg(element.key, value);
                if ( r ) break;
            }

            return r;
        }
    }


    /***************************************************************************

        Read only iterator scope class.

        The read-only iterator is more efficient as it does not require the
        copy of the items being iterated, which the safe iterator performs. The
        hashmap should not be modified while using this iterator. (The values of
        mappings may be modified while iterating, at the user's discretion.)

    ***************************************************************************/

    public scope class ReadOnlyIterator
    {
        public int opApply ( int delegate ( ref Bucket.Element.Key, ref V* ) dg )
        {
            int r;

            scope it = this.outer.new ReadOnlyElementsIterator;
            foreach ( element; it )
            {
                auto value = cast(V*)element.val.ptr;
                r = dg(element.key, value);
                if ( r ) break;
            }

            return r;
        }
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
            scope ( exit ) Stdout.formatln("{} unittest ---------------",
               typeof(this).stringof);
        }

        scope map = new typeof(this)(10);

        debug ( UnittestVerbose ) void printState ( )
        {
            Stdout.formatln("  ::  len={}, load={}, max_load={}, pool={} ({} busy)",
                map.length, map.load, map.max_load,
                map.bucket_elements.length, map.bucket_elements.num_busy);
        }

        bool lengthIs ( int expected )
        {
            assert(map.length == expected);

            int c;
            scope it = map.new ReadOnlyIterator;
            foreach ( k, v; it )
            {
                c++;
            }
            return c == expected;
        }

        void put ( hash_t key, bool should_exist )
        {
            auto len = map.length;

            assert(!!(key in map) == should_exist);

            auto e = map.put(key);
            debug ( UnittestVerbose )
            {
                Stdout.format("put {}: {}", key, e);
                printState();
            }

            assert(key in map);
            assert(*(key in map) == V.init);
            assert(lengthIs(len + (should_exist ? 0 : 1)));
        }

        void remove ( hash_t key, bool should_exist )
        {
            auto len = map.length;
            auto pool_len = map.bucket_elements.length;

            assert(!!(key in map) == should_exist);

            auto e = map.remove(key);
            debug ( UnittestVerbose )
            {
                Stdout.format("remove {}: {}", key, e);
                printState();
            }

            assert(!(key in map));
            assert(lengthIs(len - (should_exist ? 1 : 0)));
            assert(pool_len == map.bucket_elements.length);
        }

        void clear ( )
        {
            auto pool_len = map.bucket_elements.length;

            map.clear();
            debug ( UnittestVerbose )
            {
                Stdout.format("clear");
                printState();
            }

            assert(lengthIs(0));

            assert(pool_len == map.bucket_elements.length);
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

//        foreach (i, bucket; map.buckets)
//        {
//            Stdout.formatln("Bucket {,2}: {,2} elements:", i, bucket.length);
//            foreach ( element; bucket )
//            {
//                Stdout.formatln("  {,2}->{,2}", element.key,
//                    *(cast(V*)element.val.ptr));
//            }
//        }
    }
}

