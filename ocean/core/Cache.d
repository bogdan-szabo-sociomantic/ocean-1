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

// *****************************************************************************
// *****************************************************************************
// *****************************************************************************
pragma(msg, "ocean.core.Cache is deprecated: use ocean.util.container.Cache instead");
// *****************************************************************************
// *****************************************************************************
// *****************************************************************************




/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ArrayMap;

private import ocean.db.ebtree.EBTree128;

private import tango.stdc.time: time_t;

debug private import ocean.io.Stdout;

debug (CacheTimes)
{
    private import ocean.core.Array: concat;
    private import tango.stdc.stdio: FILE, fopen, fclose, fprintf, perror;
    private import tango.stdc.posix.time: ctime_r;
}

abstract class ICache
{
    /***************************************************************************
    
        The cache size in (maximum number of items) as passed to constructor.
    
    ***************************************************************************/
    
    public const size_t max_length;
    
    /***************************************************************************
    
        Real-time flag. true means that the time is monotonic increasing.
        
        If true, the access methods assert that the access time passed is always
        at least the value of the accessed cache element.
        If false and an element is attempted to access whose access time is
        greater than the time value passed to the access method, the access is
        denied: On 'put' access the element is not updated or added and a 'Get'
        access behaves as if the element could not be found. 
    
    ***************************************************************************/
    
    public bool realtime = true;
    
    /***************************************************************************

        Insert position into array of items.
    
    ***************************************************************************/
    
    private size_t insert;
    
    
    /***************************************************************************
    
        Mapping from access time to the index of an item in the items array. The
        map is implemented with an EBTree, so that it is sorted in order of
        access times.
        
        The time-to-index mapping records are stored in time_to_index as
        so-called EBTree "nodes" of type TimeToIndex.Node. Each node contains a
        so-called "key" of type TimeToIndex.Key which consists of two uint
        values, "lo" and "hi".
        The sort order is ascending by "hi"; records with the same "hi" value
        are sorted by "lo". Therefore, since the time-to-index mapping records
        should be sorted by access time, time and cache index are stored as
        
            TimeToIndex.Key.hi = access time,
            TimeToIndex.Key.lo = cache index.
        
    ***************************************************************************/
    
    protected alias EBTree128!() TimeToIndex;
    
    private const TimeToIndex time_to_index;
    
    
    /***************************************************************************
    
        Mapping from key to TimeToIndex.Mapping struct (which contains a mapping
        from an access time to the index of an elements in this.items).
    
    ***************************************************************************/
    
    protected alias ArrayMap!(TimeToIndex.Node*, hash_t) KeyToNode;
    
    private const KeyToNode key_to_node;
    
    
    /***************************************************************************
    
        Constructor.
    
        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed
    
    ***************************************************************************/
    
    protected this ( size_t max_items )
    {
        this.insert = 0;
    
        this.time_to_index = new TimeToIndex;
        this.key_to_node = new KeyToNode(this.max_length = max_items);
    }
    
    /***************************************************************************

        Removes all items from the cache.
    
    ***************************************************************************/
    
    public void clear ( )
    {
        this.time_to_index.clear();
        this.key_to_node.clear();
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

        Checks whether an item exists in the cache.
    
        Params:
            key = key to lookup
    
        Returns:
            true if item exists in cache
    
    ***************************************************************************/
    
    public bool exists ( hash_t key )
    {
        return (key in this) !is null;
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
        TimeToIndex.Node** node = key in this;
        
        if (node)
        {
            this.remove_(key, **node);
            return true;
        }
        else
        {
            return false;
        }
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
        TimeToIndex.Node** node = key in this;
        
        if ( node is null )
        {
            return 0;
        }
        else
        {
            return (*node).key.hi;
        }
    }
    
    /***************************************************************************
        
        Obtains the index of the cache item that corresponds to node and updates
        the access time.
        If realtime is enabled, access_time is expected to be equal to or
        greater than the time stored in node. If disabled and the access time is
        less, the node will not be updated and a value of at least length
        returned.
        
        
        Params:
            node        = time-to-index tree node
            access_time = access time
        
        Returns:
            the index of the corresponding cache item or a value of at least
            length if realtime is disabled and the access time is less than the
            access time in the node.
    
        Out:
            If realtime is enabled, the returned index is less than length.
    
    ***************************************************************************/
    
    protected size_t get_ ( ref TimeToIndex.Node node, time_t access_time )
    out (index)
    {
        if (this.realtime)
        {
            assert (index < this.insert);
        }
    }
    body
    {
        TimeToIndex.Key key = node.key;
        
        if (access_time >= key.hi)
        {
            key.hi = access_time;
            
            this.time_to_index.update(node, key);
            
            return key.lo;
        }
        else
        {
            assert (!this.realtime, "attempted to obtain a record in the future");
            
            return size_t.max;
        }
    }
    
    /***************************************************************************
    
        Obtains the index of the cache item that corresponds to key and updates
        the access time.
        If realtime is enabled and key could be found, access_time is expected
        to be at least the time value stored in node. If disabled and
        access_time is less, the result is the same as if key could not be
        found.
        
        
        Params:
            node        = time-to-index tree node
            access_time = access time
        
        Returns:
            the index of the corresponding cache item or a value of at least
            length if key could not be found or realtime is disabled and the
            access time is less than the access time in the cache element.
    
    ***************************************************************************/
    
    protected size_t get_ ( hash_t key, lazy time_t access_time )
    {
        TimeToIndex.Node** node = key in this;
        
        return node? this.get_(**node, access_time) : size_t.max;
    }
    
    /***************************************************************************
        
        Obtains the time-to-index node for key.
        
        Params:
            key = key to lookup
        
        Returns:
            pointer to the time-to-index node for key or null if not found.
            
        Out:
            If found, it is safe to dereference the pointer to which the
            returned pointer points (*node is not null).  
    
    ***************************************************************************/
    
    protected TimeToIndex.Node** opIn_r ( hash_t key )
    out (node)
    {
        if (node) assert (*node, "null pointer value was stored in key_to_node");
    }
    body
    {
        return key in this.key_to_node;
    }
    
    /***************************************************************************
    
        Registers a new cache element and obtains the cache item index for it.
        If the cache is full, the oldest cache element is replaced.
        If realtime is enabled, time is expected to be at least the time value
        of the most recent cache element.
        If realtime is disabled and time is less than the time value of the most
        recent cache element, nothing is done and a value of at least length is
        returned.
        
        Params:
            key  = cache element key
            time = cache element creation time
        
        Returns:
            the index of the cache item that corresponds to the newly registered
            cache element or a value of at least length if realtime is disabled
            and time is less than the time value of the most recent cache
            element.
        
        In:
            If realtime is enabled, time must bebe at least the time value of
            the most recent cache element. 
         
        Out:
            If realtime is enabled, the returned index is below length.
    
    ***************************************************************************/
    
    protected size_t register ( hash_t key, time_t time )
    in
    {
        if (this.realtime && this.insert)
        {
            TimeToIndex.Node* newest_time_node = this.time_to_index.last;
            assert (newest_time_node);
            assert (newest_time_node.key.hi <= time,
                    "attempting to register a cache entry older than the newest");
        }
    }
    out (index)
    {
        if (this.realtime)
        {
            assert (index < this.insert);
        }
    }
    body
    {
        size_t index;
        
        if ( this.insert < this.max_length )
        {
            index = this.insert++;
        }
        else
        {
            // Find item with lowest (ie oldest) update time
            TimeToIndex.Node* oldest_time_node = this.time_to_index.first;
            
            assert (oldest_time_node);
            
            with (oldest_time_node.key) // struct { time_t hi; size_t lo; }
            {
                if (time < hi) // time is before the oldest cache entry: abort
                {
                    assert (!this.realtime);
                    
                    return index.max;
                }
                
                index = lo;
            }

            // Remove old item in tree map
            this.time_to_index.remove(*oldest_time_node);
            
            this.key_to_node.remove(this.keyByIndex(index));
        }
        
        this.key_to_node.put(key,
                             this.time_to_index.add(TimeToIndex.Key(index,
                                                                    time)));
        
        return index;
    }
    
    /***************************************************************************
    
        Obtains the key of the cache item corresponding to index.
        
        Params:
            index = cache item index, guaranteed to be below length 
        
        Returns:
            cache item key
        
    ***************************************************************************/
    
    abstract protected hash_t keyByIndex ( size_t index );
    
    /***************************************************************************
    
        Removes the cache item that corresponds to dst_key and dst_node.
        
        Params:
            dst_key  = key of item to remove
            dst_node = time-to-index tree node to remove 
        
    ***************************************************************************/
    
    protected void remove_ ( hash_t dst_key, ref TimeToIndex.Node dst_node )
    {
        /* 
         * Remove item in items list by copying the last item to the item to
         * remove and decrementing the insert index which reflects the
         * actual number of items.
         */
        
        this.insert--;
        
        size_t index = dst_node.key.lo;
        
        if ( index != this.insert )
        {
            hash_t src_key = this.copyLast(index, this.insert);
            
            /*
             * Obtain the time-to-mapping entry for the copied cache item.
             * Update it to the new index and update the key-to-mapping
             * entry to the updated time-to-mapping entry. 
             */
            
            TimeToIndex.Node* src_node = this.key_to_node.get(src_key);
            
            assert (src_node);
            
            this.key_to_node.put(src_key, src_node);
            
            TimeToIndex.Key src_node_key = src_node.key;
            
            src_node_key.lo = index;
            
            this.key_to_node.put(src_key,
                                 this.time_to_index.update(*src_node,
                                                           src_node_key));
        }

        // Remove the tree map entry of the removed cache item. 
        this.time_to_index.remove(dst_node);

        // Remove key -> item mapping
        this.key_to_node.remove(dst_key);
    }
    
    /***************************************************************************
    
        Copies the cache item with index src to dst, overwriting the previous
        content of the cache item with index dst.
        Unlike all other situations where indices are used, src is always valid
        although it may be (and actually is) equal to length. However, src is
        still guaranteed to be less than max_length so it is safe to use src for
        indexing.
        
        Params:
            dst = destination cache item index, guaranteed to be below length 
            src = source cache item index, guaranteed to be below max_length 
        
        Returns:
            the key of the copied cache item.
        
    ***************************************************************************/
    
    abstract protected hash_t copyLast ( size_t dst, size_t src );
}

/*******************************************************************************

    Extends ICache by tracking the creation time of each cache element. 
    
*******************************************************************************/
    
abstract class ITrackCreateTimesCache : ICache
{
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
    
    /*******************************************************************************
    
        Obtains the creation time for the cache element corresponding to key.
        
        Params:
            key = cache element key
            
        Returns:
            the creation time of the corresponding element or 0 if not found.
        
    *******************************************************************************/
        
    abstract public time_t createTime ( hash_t key );
}

/*******************************************************************************

    Evaluates to either ICache or ITrackCreateTimesCache, depending on
    TrackCreateTimes.

*******************************************************************************/

template CacheBase ( bool TrackCreateTimes = false )
{
    static if (TrackCreateTimes)
    {
        alias ITrackCreateTimesCache CacheBase;
    }
    else
    {
        alias ICache CacheBase;
    }
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

class Cache ( size_t ValueSize = 0, bool TrackCreateTimes = false ) : CacheBase!(TrackCreateTimes)
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
    
        Constructor.
    
        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed
    
    ***************************************************************************/
    
    public this ( size_t max_items )
    {
        super(max_items);
        
        this.items = new CacheItem[max_items];
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
        CacheItem* item = this.get__(key, time);
        
        if (item)
        {
            item.setValue(value);
            
            return true;
        }
        else
        {
            Value* dst_value = this.add(key, time);
            
            if (dst_value)
            {
                CacheItem.setValue(*dst_value, value);
            }
            else
            {
                assert (!this.realtime,
                        "attempted to access a cache item whose time of last "
                        "access is in the future");
            }
            
            return false;
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
        CacheItem* item = this.get__(key, access_time);
        
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
    out (val)
    {
        if (this.realtime)
        {
            assert (val);
        }
    }
    body
    {
        CacheItem* item = this.get__(key, access_time);
        
        existed = item !is null;
        
        return item? &item.value : this.add(key, access_time);
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
            TimeToIndex.Node** node = key in this;
            
            return node? this.items[(*node).key.lo].create_time : 0;
        }
    }


    /***************************************************************************
    
        Obtains the key of the cache item corresponding to index.
        
        Params:
            index = cache item index, guaranteed to be below length 
        
        Returns:
            cache item key
        
    ***************************************************************************/
    
    protected hash_t keyByIndex ( size_t index )
    in
    {
        assert (index <= this.length);
    }
    body
    {
        return this.items[index].key;
    }
    
    /***************************************************************************
    
        Copies the cache item with index src to dst, overwriting the previous
        content of the cache item with index dst.
        Unlike all other situations where indices are used, src is always valid
        although it may be (and actually is) equal to length. However, src is
        still guaranteed to be less than max_length so it is safe to use src for
        indexing.
        
        Params:
            dst = destination cache item index, guaranteed to be below length 
            src = source cache item index, guaranteed to be below max_length 
        
        Returns:
            the key of the copied cache item.
        
    ***************************************************************************/
    
    protected hash_t copyLast ( size_t dst, size_t src )
    in
    {
        assert (src < this.max_length);
        assert (dst < this.length);
    }
    body
    {
        /* 
         * src_item: last item in elements to be copied to the item to
         *           remove.
         */
        
        CacheItem src_item = this.items[src];
        
        /*
         * Copy the last item to the item to remove. dst_node.index
         * is the index of the element to remove in this.items.
         */
        
        with (this.items[dst])
        {
            setValue(src_item.value);
            return key = src_item.key;
        }
    }
    
    /***************************************************************************
    
        Obtains the cache item that corresponds to node and updates the access
        time.
        If realtime is enabled, time is expected to be equal to or
        greater than the time stored in node. If disabled and the access time is
        less, the node will not be updated and null returned.
        
        
        Params:
            node = time-to-index tree node
            time = access time
        
        Returns:
            the cache item or a null if realtime is disabled and the access time
            is less than the access time in the node.
    
        Out:
            If realtime is enabled, the returned pointer is never null.
    
    ***************************************************************************/
    
    protected CacheItem* get__ ( ref TimeToIndex.Node node, lazy time_t time )
    out (item)
    {
        if (this.realtime)
        {
            assert (item);
        }
    }
    body
    {
        return this.getItem(this.get_(node, time));
    }
    
    /***************************************************************************
    
        Obtains the cache item that corresponds to node and updates the access
        time.
        If realtime is enabled and key could be found, time is expected to be at
        least the time value stored in node. If disabled and access_time is
        less, the result is the same as if key could not be found.
        
        
        Params:
            node = time-to-index tree node
            time = access time
        
        Returns:
            the corresponding cache item or null if key could not be found or
            realtime is disabled and the access time is less than the access
            time in the cache element.
    
    ***************************************************************************/
    
    protected CacheItem* get__ ( hash_t key, lazy time_t time )
    {
        return this.getItem(this.get_(key, time));
    }
    
    /***************************************************************************
    
        Obtains the cache item that corresponds to index. Returns null if index
        is length or greater.
        
        Params:
            index = cache item index
        
        Returns:
            the corresponding cache item or null if index is length or greater.
    
    ***************************************************************************/
    
    private CacheItem* getItem ( size_t index )
    {
        return (index < this.length)? &this.items[index] : null;
    }
    
    /***************************************************************************

        Adds an item to the cache. If the cache is full, the oldest item will be
        removed and replaced with the new item.

        If realtime is enabled, time is expected to be at least the time value
        of the most recent cache element.
        If realtime is disabled and time is less than the time value of the most
        recent cache element, nothing is done and null is returned.
        
        Params:
            key = key of item
            time = create time of item (set as initial access time)
        
        Returns:
            pointer to value of added item to be written to by caller or null 
            f realtime is disabled and time is less than the time value of the
            most recent cache element.
        
        In:
            If realtime is enabled, time must be at least the time value of the
            most recent cache element. 
         
        Out:
            If realtime is enabled, the returned pointer is never null.
            
    ***************************************************************************/

    private Value* add ( hash_t key_in, time_t time )
    out (val)
    {
        if (this.realtime)
        {
            assert (val);
        }
    }
    body
    {
        size_t index = this.register(key_in, time);
        
        if (index < this.length)
        {
            // Add key->item mapping
            
            with (this.items[index])
            {
                // Set key & value in chosen element of items array
                key = key_in;
                
                static if ( TrackCreateTimes )
                {
                    create_time = time;
                }
                
                return &value;
            }
        }
        else
        {
            return null;
        }
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

    public bool exists ( hash_t key, lazy time_t access_time )
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
    
        Obtains the cache item for key.
        
        Params:
            key          = key of item to remove
            access_time_ = current time
        
        Returns:
            the obtained cache item 
    
    ***************************************************************************/

    private CacheItem* getRemove ( hash_t key, lazy time_t access_time_ )
    {
        TimeToIndex.Node**  node = key in this;
        
        CacheItem* cache_item = null;
        
        if (node)
        {
            /*
             * If there is a node, there is also a cache item. get__() will only
             * return null if the current access time of the item is later than
             * access_time. This can only happen if realtime is disabled.
             */
            
            time_t access_time = access_time_;
            
            cache_item = this.get__(**node, access_time);
            
            if (cache_item)
            {
                if (cache_item.create_time > access_time ||
                    access_time - cache_item.create_time >= this.lifetime)
                {
                    this.stats.expired++;
                    
                    this.remove_(key, **node);
                    cache_item = null;
                }
            }
            else
            {
                assert (!this.realtime,
                        "attempted to access a cache item whose time of last "
                        "access is in the future");
            }
        }
        
        this.stats.total++;
        
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

import tango.stdc.posix.stdlib: srand48, mrand48, drand48;
import tango.stdc.time: time;

import tango.io.Stdout;

import ocean.core.Array: shuffle;

extern (C) int getpid();

unittest
{
    srand48(time(null)+getpid());
    
    static ulong ulrand ( )
    {
        return (cast (ulong) mrand48() << 0x20) | cast (uint) mrand48();
    }

    time_t time = 234567;

    // ---------------------------------------------------------------------
    // Test of static sized cache
    
    version (all)
    {{
        const n_records  = 33,
              capacity   = 22,
              n_overflow = 7;
       
        static assert (n_records >= capacity, 
                       "Number of records smaller than capacity!");

        struct Record
        {
            hash_t key; // random number
            int    val; // counter
        }
        
        // Initialise the list of records.
        
        Record[n_records] records;
        
        foreach (i, ref record; records)
        {
            record = Record(ulrand(), i);
        }
        
        // Populate the cache to the limit.
        
        scope cache = new Cache!(int)(capacity);
        
        assert (capacity == cache.max_length, 
                "Max length of cache does not equal configured capacity!");

        time_t t = 0;
        
        foreach (record; records[0 .. cache.max_length])
        {
            cache.putItem(record.key, ++t, record.val);
        }
        
        assert (t == cache.max_length);
        
        // Shuffle records and count how many of the first n_overflow of the
        // shuffled records are in the cache. If either all or none of these are
        // in the cache, shuffle and try again.
        
        uint n_existing;
       
        do
        {
            n_existing = 0;
            foreach (i, record; records.shuffle(drand48)[0 .. n_overflow])
            {
                n_existing += cache.exists(record.key);
            }
        }
        while (!n_existing || n_existing == n_overflow)
       
        assert (n_existing > 0 && n_existing < n_overflow, "n_existing has unexpected value");

        // Get the shuffled records from the cache and verify them. Record the
        // keys of the first n_overflow existing records which will get the
        // least (oldest) access time by cache.getItem() and therefore be the
        // first records to be removed on a cache overflow. 
        
        hash_t[n_overflow] oldest_keys;
        
        {
            uint i = 0;
            
            foreach (record; records)
            {
                int* v = cache.getItem(record.key, ++t);
                
                if (record.val < cache.max_length)
                {
                    assert (v !is null);
                    assert (*v == record.val);
                    
                    if (i < n_overflow)
                    {
                        oldest_keys[i++] = record.key;
                    }
                }
                else
                {
                    assert (v is null);
                }
            }

            assert (i == n_overflow);
        }
        
        assert (t == cache.max_length * 2);
        
        // Put the first n_overflow shuffled records so that the cache will
        // overflow.
        // Existing records should be updated to a new value. To enable
        // verification of the update, change the values to 4711 + i.
        
        foreach (i, ref record; records[0 .. n_overflow])
        {
            record.val = 4711 + i;
            
            cache.putItem(record.key, ++t, record.val);
        }
        
        assert (t == cache.max_length * 2 + n_overflow);
        
        // Verify the records.
        
        foreach (i, record; records[0 .. n_overflow])
        {
            int* v = cache.getItem(record.key, ++t);
            
            assert (v !is null);
            assert (*v == 4711 + i);
        }
        
        assert (t == cache.max_length * 2 + n_overflow * 2);
        
        // oldest_keys[n_existing .. $] should have been removed from the
        // cache due to cache overflow.
        
        foreach (key; oldest_keys[n_existing .. $])
        {
            int* v = cache.getItem(key, ++t);
            
            assert (v is null);
        }
        
        // cache.getItem should not have evaluated the lazy ++t.
        
        assert (t == cache.max_length * 2 + n_overflow * 2);
        
        // Verify that all other records still exist in the cache.
        
        {
            uint n = 0;
            
            foreach (record; records[n_overflow .. $])
            {
                int* v = cache.getItem(record.key, ++t);
                
                if (v !is null)
                {
                    assert (*v == record.val);
                    
                    n++;
                }
            }
            
            assert (n == cache.max_length - n_overflow);
        }
        
        assert (t == cache.max_length * 3 + n_overflow);
    }}
    else
    {
        struct Data
        {
            int x;
        }
        
        scope static_cache = new Cache!(Data)(2);
        
        with (static_cache)
        {
            assert(length == 0);
        
            {
                bool replaced = putItem(1, time, Data(23));
                
                assert(!replaced);
                
                assert(length == 1);
                assert(exists(1));
                
                Data* item = getItem(1, time);
                assert(item);
                assert(item.x == 23);
            }
            
            {
                bool replaced = putItem(2, time + 1, Data(24));
                
                assert(!replaced);
                
                assert(length == 2);
                assert(exists(2));
                
                Data* item = getItem(2, time + 1);
                assert(item);
                assert(item.x == 24); 
            }
            
            {
                bool replaced = putItem(2, time + 1, Data(25));
                
                assert(replaced);
                
                assert(length == 2);
                assert(exists(2));
                
                Data* item = getItem(2, time + 1);
                assert(item);
                assert(item.x == 25);
            }
        
            {
                bool replaced = putItem(3, time + 2, Data(26));
                
                assert(!replaced);
                
                assert(length == 2);
                assert(!exists(1));
                assert(exists(2));
                assert(exists(3));
                
                Data* item = getItem(3, time + 2);
                assert(item);
                assert(item.x == 26);
            }
            
            {
                bool replaced = putItem(4, time + 3, Data(27));
                
                assert(!replaced);
                
                assert(length == 2);
                assert(!exists(1));
                assert(!exists(2));
                assert(exists(3));
                assert(exists(4));
                
                Data* item = getItem(4, time + 3);
                assert(item);
                assert(item.x == 27);
            }
            
            clear();
            assert(length == 0);
        
            {
                bool replaced = putItem(1, time, Data(23));
                
                assert(!replaced);
                
                assert(length == 1);
                assert(exists(1));
                
                Data* item = getItem(1, time);
                assert(item);
                assert(item.x == 23);
            }
            
            {
                bool replaced = putItem(2, time + 1, Data(24));
                
                assert(!replaced);
                
                assert(length == 2);
                assert(exists(2));
                
                Data* item = getItem(2, time + 1);
                assert(item);
                assert(item.x == 24);
            }
            
            remove(1);
            assert(length == 1);
            assert(!exists(1));
            assert(exists(2));
        }
    }
    
    // ---------------------------------------------------------------------
    // Test of expiring cache
    
    {
        ubyte[] data1 = cast(ubyte[])"hello world";
        ubyte[] data2 = cast(ubyte[])"goodbye world";
        ubyte[] data3 = cast(ubyte[])"hallo welt";
        
        time_t t = 0;
        
        scope expiring_cache = new ExpiringCache!()(4, 10);
        
        with (expiring_cache)
        {
            assert(length == 0);
        
            put(1, t++, data1);
            assert(length == 1);
            assert(exists(1, t++));
            {
                ubyte[]* data = get(1, t++);
                assert(data);
                assert(*data == data1);
            }
            
            assert(t <= 5);
            t = 5;
            
            put(2, t++, data2);
            assert(length == 2);
            assert(exists(2, t++));
            {
                ubyte[]* data = get(2, t++);
                assert(data);
                assert(*data == data2);
            }
            
            assert(t <= 10);
            t = 10;
            
            assert(!exists(1, t++));
            
            assert(t <= 17);
            t = 17;
            
            {
                ubyte[]* data = get(2, t++);
                assert(!data);
            }
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

version (CacheTest) void main ( ) { }
