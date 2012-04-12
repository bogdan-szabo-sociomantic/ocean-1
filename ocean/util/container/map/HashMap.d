/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        11/04/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    TODO: description of module

*******************************************************************************/

module ocean.util.container.map.HashMap;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.map.model.BucketSet;

private import ocean.util.container.map.Bucket;

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
                than 0.

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

        Adds or updates a mapping from the specified key. The value mapped to is
        set to the specified value. (Note that arrays are *not* copied into the
        value -- this must be done manually if desired.)

        Params:
            key = key to add/update mapping for
            val_in = value to set

        Returns:
            pointer to the value mapped to by the specified key

    ***************************************************************************/

    public V* put ( hash_t key, V val_in )
    {
        auto val = this.put(key);

        *val = val_in;

        return val;
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

        void printState ( )
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

            auto e = map.put(key, V.init);
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

