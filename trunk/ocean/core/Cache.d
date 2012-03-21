/*******************************************************************************

    Cache class, caches raw data of either fixed or dynamic length

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Cache of raw data (ubyte[] / void[]) items of either fixed or variable
    length. The cache is initialised with a fixed capacity (the number of items
    that can be stored). When the cache reaches its full capacity, any newly
    added items will replace older items in the cache. The cache keeps track of
    the last time each item was written or read, and will replace the oldest
    items first.

    The basic Cache template is used to store raw data. A second template exists
    which takes a type as its parameter. This implements a thin wrapper around
    the basic Cache, allowing the transparent storage of (no-op) serialized
    values of the specified type.

    Note: items are always copied into the cache, not sliced.

    Link with:
        -Llibebtree.a

    Usage example:

    ---

        import ocean.core.Cache;

        // Create a dynamic-size cache which can store 2 items.
        auto cache = new Cache!()(2);

        // Add an item.
        hash_t key = 0x12345678;
        time_t time = 0x87654321;
        ubyte[] value = cast(ubyte[])"hello world";

        cache.put(key, time, value);

        // Check if an item exists.
        auto exists = cache.exists(key);

        // Get an item and update its access timestamp.
        auto item = cache.get(key, time + 10);

    ---

*******************************************************************************/

module ocean.core.Cache;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ArrayMap;

private import ocean.db.ebtree.EBTreeMap;

private import tango.stdc.time: time_t;

debug private import ocean.io.Stdout;

debug (CacheTimes)
{
    private import ocean.core.Array: concat;
    private import tango.stdc.stdio: FILE, fopen, fclose, fprintf, perror;
    private import tango.stdc.posix.time: ctime_r;
}

/*******************************************************************************

    Data cache class template. Stores items of raw data, either of fixed or
    dynamic size.

    Template params:
        ValueSize = size of a data item. If 0 is specified (the default), the
            items stored in the cache are of variable (dynamic) size
        TrackCreateTimes = if true, each cache item is stored with its create
            time, in addition to its last access time

*******************************************************************************/

class Cache ( size_t ValueSize = 0, bool TrackCreateTimes = false )
{
    /***************************************************************************

        Alias for value type stored in cache.

    ***************************************************************************/

    static if ( ValueSize == 0 )
    {
        private const Dynamic = true;

        private alias ubyte[] Value;
    }
    else
    {
        private const Dynamic = false;

        private alias ubyte[ValueSize] Value;
    }


    /***************************************************************************

        Cached item struct, storing a key and value.

    ***************************************************************************/

    struct CacheItem
    {
        hash_t key;
        Value value;

        static if ( TrackCreateTimes )
        {
            time_t create_time;
        }
        
        /***********************************************************************

            Copies value to this.value.
            
            Params:
                value = value to copy
                
            Returns:
                this.value
    
        ***********************************************************************/

        ubyte[] setValue ( Value value )
        {
            return this.value.setValue(value);
        }
        
        /***********************************************************************

            Copies the src value to dst.
            
            Params:
                dst = destination value buffer (will be resized as required)
                src = source value
                
            Returns:
                dst
    
        ***********************************************************************/

        static if ( Dynamic ) static Value setValue ( ref Value dst, Value src )
        {
            dst.length = src.length;
            return dst[] = src[];
        }
        else static ubyte[] setValue ( Value dst, Value src )
        {
            return dst[] = src[];
        }
    }


    /***************************************************************************

        Array of cached items.

    ***************************************************************************/

    private CacheItem[] items;


    /***************************************************************************

        Insert position into array of items.

    ***************************************************************************/

    private size_t insert;


    /***************************************************************************

        Mapping from access time to the index of an item in the items array. The
        map is implemented with an EBTree, so that it is sorted in order of
        access times.

    ***************************************************************************/

    private alias EBTreeMap!(time_t, size_t) TimeToIndex;

    private TimeToIndex time_to_index;


    /***************************************************************************

        Mapping from key to TimeToIndex.Mapping struct (which contains a mapping
        from an access time to the index of an elements in this.items).

    ***************************************************************************/

    private alias ArrayMap!(TimeToIndex.Mapping, hash_t) KeyToMapping;

    private KeyToMapping key_to_mapping;


    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items )
    {
        this.items.length = max_items;
        this.insert = 0;

        this.time_to_index = new TimeToIndex;
        this.key_to_mapping = new KeyToMapping(max_items);
    }


    /***************************************************************************

        Puts an item into the cache. If the cache is full, the oldest item is
        replaced with the new item. (In the case where several items are equally
        old, the choice of which one to be replaced is made arbitrarily.)

        Params:
            key = item key
            time = item create / access time
            value = data to store in cache

        Returns:
            true if a record was updated / overwritten, false if a new record
            was added

    ***************************************************************************/

    public bool put ( hash_t key, time_t time, Value value )
    {
        TimeToIndex.Mapping* mapping = key in this.key_to_mapping;
        if ( mapping is null ) // new item, not in cache
        {
            CacheItem.setValue(*this.add(key, time), value);
            return false;
        }
        else
        {
            this.items[mapping.value].setValue(value);
            this.setAccessTime(*mapping, time);
            static if ( TrackCreateTimes )
            {
                this.items[mapping.value].create_time = time;
            }
            return true;
        }
    }


    /***************************************************************************

        Gets an item from the cache. A pointer to the item is returned, if
        found. If the item exists in the cache, its access time is updated.
    
        Note that, if you change the value pointed to by the returned pointer,
        the create time will not be updated. 

        Params:
            key = key to lookup
            access_time = new access time to set for item

        Returns:
            pointer to item value, may be null if key not found

    ***************************************************************************/

    public Value* get ( hash_t key, lazy time_t access_time )
    {
        CacheItem* item = this.get_(this.getMapping(key), access_time);
        
        return (item !is null)? &item.value : null;
    }
    
    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. A
        pointer to the item is returned, if found. If the item exists in the
        cache, its access time is updated.
        
        Note that, if the item already existed and you change the value pointed
        to by the returned pointer, the create time will not be updated. 
        
        Params:
            key         = key to lookup
            access_time = new access time to set for item
            existed     = true: the item already existed; false: the item was
                          created
        
        Returns:
            pointer to item value

    ***************************************************************************/

    public Value* getOrCreate ( hash_t key, time_t access_time, out bool existed )
    {
        TimeToIndex.Mapping* mapping = key in this.key_to_mapping;
        
        existed = mapping !is null;
        
        if ( existed )
        {
            this.setAccessTime(*mapping, access_time);
            return &this.items[mapping.value].value;
        }
        else
        {
            return this.add(key, access_time);
        }
    }
    
    /***************************************************************************

        Checks whether an item exists in the cache.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache

    ***************************************************************************/

    public bool exists ( hash_t key )
    {
        return this.getMapping(key) !is null;
    }


    /***************************************************************************

        Checks whether an item exists in the cache and returns the last time it
        was accessed.

        Params:
            key = key to lookup

        Returns:
            item's last access time, or 0 if the item doesn't exist

    ***************************************************************************/

    public time_t accessTime ( hash_t key )
    {
        TimeToIndex.Mapping* mapping = key in this.key_to_mapping;
        if ( mapping is null )
        {
            return 0;
        }
        else
        {
            return mapping.key;
        }
    }


    /***************************************************************************

        Checks whether an item exists in the cache and returns its create time.

        Params:
            key = key to lookup
    
        Returns:
            item's create time, or 0 if the item doesn't exist

    ***************************************************************************/

    static if ( TrackCreateTimes )
    {
        public time_t createTime ( hash_t key )
        {
            TimeToIndex.Mapping* mapping = key in this.key_to_mapping;
            if ( mapping is null )
            {
                return 0;
            }
            else
            {
                return this.items[mapping.value].create_time;
            }
        }
    }


    /***************************************************************************

        Removes an item from the cache.

        Params:
            key = key of item to remove

        Returns:
            returns true if removed, false if not in cache

    ***************************************************************************/

    public bool remove ( hash_t key )
    {
        return this.remove_(key, this.getMapping(key));
    }
    
    
    /***************************************************************************

        Removes all items from the cache.

    ***************************************************************************/

    public void clear ( )
    {
        this.time_to_index.clear;
        this.key_to_mapping.clear;
        this.insert = 0;
    }


    /***************************************************************************

        Returns:
            the number of items in the cache.

    ***************************************************************************/

    public size_t length ( )
    {
        return this.insert;
    }

    /***************************************************************************

        Returns:
           the cache size in (maximum number of items) as passed to constructor.
    
    ***************************************************************************/

    public size_t max_length ( )
    {
        return this.items.length;
    }
    
    /***************************************************************************
        
        Obtains the map item for key.
        
        Params:
            key = key to lookup
        
        Returns:
            pointer to map item or null if not found
    
    ***************************************************************************/

    protected TimeToIndex.Mapping* getMapping ( hash_t key )
    {
        return key in this.key_to_mapping;
    }
    
    /***************************************************************************
    
        Obtains the cache item that corresponds to map_item and updates the
        access time.
        
        Params:
            map_item    = map item (may be null)
            access_time = access time
        
        Returns:
            pointer to corresponding cache item or null if map_item is null
    
    ***************************************************************************/

    protected CacheItem* get_ ( TimeToIndex.Mapping* mapping, lazy time_t access_time )
    {
        if ( mapping !is null )
        {
            this.setAccessTime(*mapping, access_time);

            return &this.items[mapping.value];
        }
        else // Item not in cache
        {
            return null;
        }
    }
    
    /***************************************************************************
    
        Removes the cache item that corresponds to key and map_item.
        
        Params:
            dst_key      = key of item to remove
            dst_map_item = map item to remove (may be null to do nothing)
        
        Returns:
            true if removed or false if map_item is null and nothing has been
            done.
    
    ***************************************************************************/

    protected bool remove_ ( hash_t dst_key, TimeToIndex.Mapping* dst_mapping )
    {
        if ( dst_mapping is null ) // item not in cache
        {
            return false;
        }
        else
        {
            /* 
             * Remove item in items list by copying the last item to the item to
             * remove and decrementing the insert index which reflects the
             * actual number of items.
             */
            
            this.insert--;
            
            size_t index = dst_mapping.value;
            
            if ( index != this.insert )
            {
                /* 
                 * src_item: last item in elements to be copied to the item to
                 *           remove.
                 */
                
                CacheItem src_item = this.items[this.insert];
                
                /*
                 * Copy the last item to the item to remove. dst_mapping.index
                 * is the index of the element to remove in this.items.
                 */
                
                with (this.items[index])
                {
                    key =    src_item.key;
                    setValue(src_item.value);
                }
                
                /*
                 * Obtain the time-to-mapping entry for the copied cache item.
                 * Update it to the new index and update the key-to-mapping
                 * entry to the updated time-to-mapping entry. 
                 */
                
                TimeToIndex.Mapping src_mapping = this.key_to_mapping.get(src_item.key);
                
                this.key_to_mapping.put(src_item.key,
                                        this.time_to_index.update(src_mapping, src_mapping.key, dst_mapping.value));
            }

            // Remove the tree map entry of the removed cache item. 
            this.time_to_index.remove(*dst_mapping);

            // Remove key -> item mapping
            this.key_to_mapping.remove(dst_key);

            return true;
        }
    }

    /***************************************************************************

        Updates the update time of an item in the cache.

        Params:
            item = KeyToMapping map item to update
            update_time = new update time to set

    ***************************************************************************/

    private void setAccessTime ( TimeToIndex.Mapping mapping, time_t access_time )
    {
        this.time_to_index.update(mapping, access_time, mapping.value);
    }
    
    /***************************************************************************

        Adds an item to the cache. If the cache is full, the oldest item will be
        removed and replaced with the new item.

        Params:
            key = key of item
            time = create time of item (set as initial access time)
            value = data to store in cache
        
        Returns:
            pointer to value of added item to be written to by caller.
        
    ***************************************************************************/

    private Value* add ( hash_t key, time_t time )
    {
        size_t index;

        if ( this.insert < this.items.length )
        {
            index = this.insert++;
        }
        else
        {
            // Find item with lowest (ie oldest) update time
            TimeToIndex.Mapping oldest_time_mapping = this.time_to_index.firstMapping;
            index = oldest_time_mapping.value;

            // Remove old item in tree map
            this.time_to_index.remove(oldest_time_mapping);
            this.key_to_mapping.remove(this.items[index].key);
        }

        // Set key & value in chosen element of items array
        this.items[index].key = key;
        
        static if ( TrackCreateTimes )
        {
            this.items[index].create_time = time;
        }

        // Add new item to tree map
//        TimeToIndex.Mapping time_mapping = this.time_to_index.add(time, index);

        // Add key->item mapping
        this.key_to_mapping.put(key, this.time_to_index.add(time, index));
        
        return &this.items[index].value;
    }
    
    debug (CacheTimes)
    {
        /**********************************************************************

            String nul-termination buffer
            
        ***********************************************************************/

        private char[] nt_buffer;
        
        /**********************************************************************

            Writes the access times and the number of records with that time to
            a file, appending to that file.
            
        ***********************************************************************/

        void dumpTimes ( char[] filename, time_t now )
        {
            FILE* f = fopen(this.nt_buffer.concat(filename, "\0").ptr, "a");
            
            if (f)
            {
                scope (exit) fclose(f);
                
                char[26] buf;
                
                fprintf(f, "> %10u %s", now, ctime_r(&now, buf.ptr));
                
                TimeToIndex.Mapping mapping = this.time_to_index.firstMapping;
                
                if (mapping)
                {
                    time_t t = mapping.key;
                    
                    uint n = 0;
                    
                    foreach (time_t u; this.time_to_index)
                    {
                        if (t == u)
                        {
                            n++;
                        }
                        else
                        {
                            fprintf(f, "%10u %10u\n", t, n);
                            t = u;
                            n = 0;
                        }
                    }
                }
            }
            else
            {
                perror(this.nt_buffer.concat("unable to open \"", filename, "\"\0").ptr);
            }
        }
    }
}

/*******************************************************************************

    Data cache class template with element life time limitation. Stores items of
    raw data, either of fixed or dynamic size. When the life time of an item,
    which is the difference between its creation time and the current wall clock
    time, has expired, it is removed automatically on the next get()/exists()
    access.
    
    Template params:
        ValueSize = size of a data item. If 0 is specified (the default), the
            items stored in the cache are of variable (dynamic) size

*******************************************************************************/

class ExpiringCache ( size_t ValueSize = 0 ) : Cache!(ValueSize, true)
{
    /***************************************************************************
    
        Life time for all items in seconds; may be changed at any time.
        This value must be at least 1.
    
    ***************************************************************************/

    public time_t lifetime;
    
    /***************************************************************************
    
        Statistics counters for get()/exists() calls, caches misses and expired
        elements. 
    
    ***************************************************************************/

    struct GetExpiredStats
    {
        /**********************************************************************
        
            total   = total number of get()/exists() calls so far,
            misses  = number of get()/exists() calls that returned no value
                      because the element was either not in the cache or was
                      removed because it was expired,
            expired = number of get()/exists() calls that found but removed the
                      element because it was expired.
        
        ***********************************************************************/

        uint total, misses, expired;
    }
    
    /***************************************************************************
    
        Statistics counters 
    
    ***************************************************************************/

    private GetExpiredStats stats;
    
    /***************************************************************************
    
        Invariant
    
    ***************************************************************************/

    invariant ( )
    {
        assert (this.lifetime >= 0);
    }
    
    /***************************************************************************

        Constructor.
    
        Params:
            max_items = maximum number of items in the cache, set once, cannot
                        be changed
            lifetime  = life time for all items in seconds; may be changed at
                        any time. This value must be at least 1.
    
    ***************************************************************************/

    public this ( size_t max_items, time_t lifetime )
    {
        super(max_items);
        
        this.lifetime = lifetime;
    }
    
   /***************************************************************************
    
        Gets an item from the cache. A pointer to the item is returned, if
        found. If the item exists in the cache, its access time is updated.
        If the item life time has expired, it is removed.
    
        Note that, if you change the value pointed to by the returned pointer,
        the create time will not be updated. 

        Params:
            key = key to lookup
            access_time = new access time to set for item

        Returns:
            pointer to item value, may be null if either the key was not found
            or the item has been removed because its life time has expired.
    
    ***************************************************************************/

    override Value* get ( hash_t key, lazy time_t access_time )
    {
        CacheItem* cache_item = this.getRemove(key, access_time);
        
        return cache_item? &cache_item.value : null;
    }
    
    /***************************************************************************

        Checks whether an item exists in the cache and updates its access time.
        If the life time of the item has expired, it is removed.
    
        Params:
            key = key to lookup
    
        Returns:
            true if item exists in cache and its life time is not yet expired.
    
    ***************************************************************************/

    public bool exists ( hash_t key, time_t access_time )
    {
        return this.getRemove(key, access_time) !is null;
    }
    
    /***************************************************************************
    
        Obtains the statistics counters for get()/exists() calls, caches misses
        and expired elements. 
        
        Params:
            reset = set to true to reset the counters to zero.
            
        Returns:
            statistics counters.
        
    ***************************************************************************/

    public GetExpiredStats get_remove_stats ( bool reset = false )
    {
        scope (success) if (reset)
        {
            this.stats = this.stats.init;
        }
        
        return this.stats;
    }
    
    /***************************************************************************
    
        Obtains the cache item for key
        
        Params:
            key      = key of item to remove
            map_item = map item (may be null)
        
        Returns:
            true if removed or false if map_item is null and nothing has been
            done.
    
    ***************************************************************************/

    private CacheItem* getRemove ( hash_t key, time_t access_time )
    {
        TimeToIndex.Mapping*   mapping    = super.getMapping(key);
        CacheItem* cache_item             = super.get_(mapping, access_time);
        
        this.stats.total++;
        
        if (cache_item)
        {
            if (cache_item.create_time > access_time || access_time - cache_item.create_time >= this.lifetime)
            {
                this.stats.expired++;
                
                super.remove_(key, mapping);
                cache_item = null;
            }
        }
        
        this.stats.misses += !cache_item;
        
        return cache_item;
    }
}


/*******************************************************************************

    Typed cache class template. Stores items of a particular type.

    Template params:
        T = type of item to store in cache
        TrackCreateTimes = if true, each cache item is stored with its create
            time, in addition to its last access time

*******************************************************************************/

class Cache ( T, bool TrackCreateTimes = false ) : Cache!(T.sizeof, TrackCreateTimes)
{
    /***************************************************************************

        Alias for an array of raw data the same size as the template type.

    ***************************************************************************/

    private alias ubyte[T.sizeof] RawValue;


    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items )
    {
        super(max_items);
    }


    /***************************************************************************

        Puts an item into the cache. If the cache is full, the oldest item is
        replaced with the new item. (In the case where several items are equally
        old, the choice of which one to be replaced is made arbitrarily.)

        Params:
            key = item key
            update_time = item update time
            value = item to store in cache

        Returns:
            true if a record was updated / overwritten, false if a new record
            was added

    ***************************************************************************/

    public bool putItem ( hash_t key, time_t update_time, T value )
    {
        return super.put(key, update_time, *cast(RawValue*)(&value));
    }


    /***************************************************************************

        Gets an item from the cache. A pointer to the item is returned, if
        found. If the item exists in the cache, its update time is updated.

        Note that, if the item already existed and you change the value pointed
        to by the returned pointer, the create time will not be updated.
         
        Params:
            key = key to lookup
            update_time = new update time to set for item

        Returns:
            pointer to item value, may be null if key not found

        FIXME: For dynamic data arrays, if Value is ubyte[], the cast won't work
        and needs to be changed to
        ---
            return raw? cast(T*)(*raw).ptr : null;
        ---
        . However, the change will likely be compatible to static arrays, too.
        
     ***************************************************************************/
    
    public T* getItem ( hash_t key, lazy time_t update_time )
    {
        auto raw = super.get(key, update_time);
        return cast(T*)raw;
    }
    
    
    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. A
        pointer to the item is returned, if found. If the item exists in the
        cache, its update time is updated.
        
        Note that, if the item already existed and you change the value pointed
        to by the returned pointer, the create time will not be updated. 
        
        Params:
            key         = key to lookup
            update_time = new update time to set for item
            existed     = true: the item already existed; false: the item was
                          created
        
        Returns:
            pointer to item value
        
        FIXME: See note about cast in getItem().
        
    ***************************************************************************/

    public T* getOrCreateItem ( hash_t key, lazy time_t update_time )
    {
        auto raw = super.get(key, update_time);
        return cast(T*)raw;
    }


    /***************************************************************************

        Overridden base class methods as private to prevent use.

    ***************************************************************************/

    private Value* get ( hash_t key, lazy time_t access_time )
    {
        assert(false);
        return null;
    }

    private bool put ( hash_t key, time_t time, Value value )
    {
        assert(false);
        return false;
    }
}

/*******************************************************************************

    Unit test

*******************************************************************************/

debug ( OceanUnitTest )
{
    unittest
    {
        time_t time = 234567;

        // ---------------------------------------------------------------------
        // Test of static sized cache
        
        {
            struct Data
            {
                int x;
            }
            
            scope static_cache = new Cache!(Data)(2);
            assert(static_cache.length == 0);
        
            static_cache.putItem(1, time, Data(23));
            assert(static_cache.length == 1);
            assert(static_cache.exists(1));
            assert(static_cache.getItem(1, time).x == 23);
        
            static_cache.putItem(2, time + 1, Data(24));
            assert(static_cache.length == 2);
            assert(static_cache.exists(2));
            assert(static_cache.getItem(2, time + 1).x == 24);
        
            static_cache.putItem(2, time + 1, Data(25));
            assert(static_cache.length == 2);
            assert(static_cache.exists(2));
            assert(static_cache.getItem(2, time + 1).x == 25);
        
            static_cache.putItem(3, time + 2, Data(26));
            assert(static_cache.length == 2);
            assert(!static_cache.exists(1));
            assert(static_cache.exists(2));
            assert(static_cache.exists(3));
            assert(static_cache.getItem(3, time + 2).x == 26);
        
            static_cache.putItem(4, time + 3, Data(27));
            assert(static_cache.length == 2);
            assert(!static_cache.exists(1));
            assert(!static_cache.exists(2));
            assert(static_cache.exists(3));
            assert(static_cache.exists(4));
            assert(static_cache.getItem(4, time + 3).x == 27);
        
            static_cache.clear();
            assert(static_cache.length == 0);
        
            static_cache.putItem(1, time, Data(23));
            assert(static_cache.length == 1);
            assert(static_cache.exists(1));
            assert(static_cache.getItem(1, time).x == 23);
        
            static_cache.putItem(2, time + 1, Data(24));
            assert(static_cache.length == 2);
            assert(static_cache.exists(2));
            assert(static_cache.getItem(2, time + 1).x == 24);
        
            static_cache.remove(1);
            assert(static_cache.length == 1);
            assert(!static_cache.exists(1));
            assert(static_cache.exists(2));
        }
    
        // ---------------------------------------------------------------------
        // Test of expiring cache
        
        {
            ubyte[] data1 = cast(ubyte[])"hello world";
            ubyte[] data2 = cast(ubyte[])"goodbye world";
            ubyte[] data3 = cast(ubyte[])"hallo welt";
            
            time_t t = 0;
            
            scope expiring_cache = new ExpiringCache!()(4, 10);
            assert(expiring_cache.length == 0);
        
            expiring_cache.put(1, t++, data1);
            assert(expiring_cache.length == 1);
            assert(expiring_cache.exists(1, t++));
            {
                ubyte[]* data = expiring_cache.get(1, t++);
                assert(data);
                assert(*data == data1);
            }
            
            assert(t <= 5);
            t = 5;
            
            expiring_cache.put(2, t++, data2);
            assert(expiring_cache.length == 2);
            assert(expiring_cache.exists(2, t++));
            {
                ubyte[]* data = expiring_cache.get(2, t++);
                assert(data);
                assert(*data == data2);
            }
            
            assert(t <= 10);
            t = 10;
            
            assert(!expiring_cache.exists(1, t++));
            
            assert(t <= 17);
            t = 17;
            
            {
                ubyte[]* data = expiring_cache.get(2, t++);
                assert(!data);
            }
        }
        
        // ---------------------------------------------------------------------
        // Test of dynamic sized cache
        
        {
            ubyte[] data1 = cast(ubyte[])"hello world";
            ubyte[] data2 = cast(ubyte[])"goodbye world";
            ubyte[] data3 = cast(ubyte[])"hallo welt";
        
            scope dynamic_cache = new Cache!()(2);
            assert(dynamic_cache.length == 0);
        
            dynamic_cache.put(1, time, data1);
            assert(dynamic_cache.exists(1));
            assert(*dynamic_cache.get(1, time) == data1);
        
            dynamic_cache.put(2, time + 1, data2);
            assert(dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
            assert(*dynamic_cache.get(1, time) == data1);
            assert(*dynamic_cache.get(2, time + 1) == data2);
        
            dynamic_cache.put(3, time + 2, data3);
            assert(!dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
            assert(dynamic_cache.exists(3));
            assert(*dynamic_cache.get(2, time + 1) == data2);
            assert(*dynamic_cache.get(3, time + 2) == data3);
        
            dynamic_cache.clear;
            assert(dynamic_cache.length == 0);
        
            dynamic_cache.put(1, time, data1);
            assert(dynamic_cache.length == 1);
            assert(dynamic_cache.exists(1));
            assert(*dynamic_cache.get(1, time) == data1);
        
            dynamic_cache.put(2, time + 1, data2);
            assert(dynamic_cache.length == 2);
            assert(dynamic_cache.exists(2));
            assert(*dynamic_cache.get(2, time + 1) == data2);
        
            dynamic_cache.remove(1);
            assert(dynamic_cache.length == 1);
            assert(!dynamic_cache.exists(1));
            assert(dynamic_cache.exists(2));
        }
    }
}



/*******************************************************************************

    Performance test

*******************************************************************************/

debug ( OceanPerformanceTest )
{
    private import tango.core.Memory;

    private import tango.math.random.Random;

    private import tango.time.StopWatch;

    unittest
    {
        GC.disable;

        Trace.formatln("Starting Cache performance test");

        auto random = new Random;

        const cache_size = 100_000;

        const max_item_size = 1024 * 4;

        StopWatch sw;

        auto cache = new Cache!()(cache_size);

        ubyte[] value;
        value.length = max_item_size;

        time_t time = 1;

        // Fill cache
        Trace.format("Filling cache:        ");
        sw.start;
        for ( uint i; i < cache_size; i++ )
        {
            cache.put(i, time, value);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        Trace.formatln("{} puts, {} puts/s", cache_size, cast(float)cache_size / (cast(float)sw.microsec / 1_000_000));

        // Put values into full cache
        const puts = 1_000_000;
        Trace.formatln("Writing to cache:   ");
        sw.start;
        for ( uint i; i < puts; i++ )
        {
            cache.put(i % cache_size, time, value);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        Trace.formatln("{} puts, {} puts/s", puts, cast(float)puts / (cast(float)sw.microsec / 1_000_000));

        // Get values from cache
        const gets = 1_000_000;
        Trace.formatln("Reading from cache: {} gets, {} gets/s", gets, cast(float)gets / (cast(float)sw.microsec / 1_000_000));
        sw.start;
        for ( uint i; i < gets; i++ )
        {
            cache.get(i % cache_size, time);
            ubyte d_time;
            random(d_time);
            time += d_time % 16;
        }
        Trace.formatln("Writing to cache: {} gets, {} gets/s", gets, cast(float)gets / (cast(float)sw.microsec / 1_000_000));

        Trace.formatln("Cache performance test finished");
    }
}

