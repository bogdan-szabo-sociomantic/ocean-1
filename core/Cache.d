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

        // Get an item and update its timestamp.
        auto item = cache.get(key, time + 10);

    ---

*******************************************************************************/

module ocean.core.Cache;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ArrayMap;

private import ocean.core.Exception;

private import ocean.db.ebtree.EBTreeMap;

private import tango.core.Traits;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Data cache class template. Stores items of raw data, either of fixed or
    dynamic size.

    Template params:
        ValueSize = size of a data item. If 0 is specified (the default), the
            items stored in the cache are of variable (dynamic) size

*******************************************************************************/

class Cache ( size_t ValueSize = 0 )
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

        Mapping from update time to the index of an item in the items array. The
        map is implemented with an EBTree, so that it is sorted in order of
        update times.

    ***************************************************************************/

    private alias EBTreeMap!(time_t, size_t) TimeToIndex;

    private TimeToIndex time_to_index;


    /***************************************************************************

        Struct storing an index into the items array and a pointer to a mapping
        in the time->index map. Structs of this type are stored in the key->item
        map, below, allowing quick lookup from an item's key to its index in the
        items array and its mapping in the time->index map.

    ***************************************************************************/

    struct MapItem
    {
        size_t index;
        TimeToIndex.Mapping* time_mapping;
    }


    /***************************************************************************

        Mapping from key to MapItem struct.

    ***************************************************************************/

    private alias ArrayMap!(MapItem, hash_t) KeyToItem;

    private KeyToItem key_to_item;


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
        this.key_to_item = new KeyToItem;
    }


    /***************************************************************************

        Puts an item into the cahce. If the cache is full, the oldest item is
        replaced with the new item. (In the case where several items are equally
        old, the choice of which one to be replaced is made arbitrarily.)

        Params:
            key = item key
            update_time = item update time
            value = data to store in cache

        Returns:
            true if a record was updated / overwritten, false if a new record
            was added

    ***************************************************************************/

    public bool put ( hash_t key, time_t update_time, Value value )
    {
        auto item = key in this.key_to_item;
        if ( item is null ) // new item, not in cache
        {
            this.add(key, update_time, value);
            return false;
        }
        else
        {
            // Update value
            this.setValue(item.index, value);

            // Update time
            this.updateTime(*item, update_time);

            return true;
        }
    }


    /***************************************************************************

        Gets an item from the cahce. A pointer to the item is returned, if
        found. If the item exists in the cahce, its update time is updated.

        Params:
            key = key to lookup
            update_time = new update time to set for item

        Returns:
            pointer to item value, may be null if key not found

    ***************************************************************************/

    public Value* get ( hash_t key, lazy time_t update_time )
    {
        auto item = key in this.key_to_item;
        if ( item is null ) // Item not in cache
        {
            return null;
        }
        else
        {
            this.updateTime(*item, update_time);

            return &this.items[item.index].value;
        }
    }


    /***************************************************************************

        Checks whether an item exists in the cahce.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache

    ***************************************************************************/

    public bool exists ( hash_t key )
    {
        auto item = key in this.key_to_item;
        return item !is null;
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
        auto item = key in this.key_to_item;
        if ( item is null ) // item not in cache
        {
            return false;
        }
        else
        {
            // Remove item in items list
            this.removeItem(key, item.index);

            // Remove item in tree map
            this.time_to_index.remove(item.time_mapping);

            // Remove key -> item mapping
            this.key_to_item.remove(key);

            return true;
        }
    }


    /***************************************************************************

        Removes all items from the cache.

    ***************************************************************************/

    public void clear ( )
    {
        this.time_to_index.clear;
        this.key_to_item.clear;
        this.insert = 0;
    }


    /***************************************************************************

        Returns:
            number of items in the cache

    ***************************************************************************/

    public size_t length ( )
    {
        return this.insert;
    }


    /***************************************************************************

        Updates the update time of an item in the cache.

        Params:
            item = KeyToItem map item to update
            update_time = new update time to set

    ***************************************************************************/

    private void updateTime ( MapItem item, time_t update_time )
    {
        this.time_to_index.update(item.time_mapping, update_time, item.index);
    }


    /***************************************************************************

        Copies the provided value into the indexed item.

        Params:
            index = index of item to copy into
            value = data to store

    ***************************************************************************/

    private void setValue ( size_t index, Value value )
    {
        static if ( Dynamic )
        {
            this.items[index].value.length = value.length;
        }

        this.items[index].value[] = value[];
    }


    /***************************************************************************

        Adds an item to the cache. If the cache is full, the oldest item will be
        removed and replaced with the new item.

        Params:
            key = key of item
            update_time = update time of item
            value = data to store in cache

    ***************************************************************************/

    private void add ( hash_t key, time_t update_time, Value value )
    {
        size_t index;

        if ( this.insert < this.items.length )
        {
            index = this.insert++;
        }
        else
        {
            // Find item with lowest (ie oldest) update time
            auto oldest_time_mapping = this.time_to_index.firstMapping;
            index = this.time_to_index.mappingValue(oldest_time_mapping);

            // Remove old item in tree map
            this.time_to_index.remove(oldest_time_mapping);
            this.key_to_item.remove(this.items[index].key);
        }

        // Set key & value in chosen element of items array
        this.setValue(index, value);
        this.items[index].key = key;

        // Add new item to tree map
        auto time_mapping = this.time_to_index.add(update_time, index);

        // Add key->item mapping
        MapItem item;
        item.index = index;
        item.time_mapping = time_mapping;
        this.key_to_item.put(key, item);
    }


    /***************************************************************************

        Removes an item from the list of cached items.

        Params:
            key = item's key
            index = index of item in items array

    ***************************************************************************/

    private void removeItem ( hash_t key, size_t index )
    {
        if ( index == this.insert - 1 )
        {
            this.insert--;
        }
        else
        {
            // Swap item to be removed with the last item in the list of cached items
            this.insert--;
            this.setValue(index, this.items[this.insert].value);

            // Update index of moved item in the key->item and time->index maps
            auto old_key = this.items[index].key;
            auto item = old_key in this.key_to_item;
            assertEx(item !is null, typeof(this).stringof ~ ".removeItem: cache inconsistency -- item not found in key map");

            item.index = index;
            this.time_to_index.update(item.time_mapping, index);

            // Replace key
            this.items[index].key = key;
        }

        // Add a time->index mapping of 0 (the oldest time), so that the last
        // item in the list will be reused first.
        this.time_to_index.add(0, this.insert);
    }
}



/*******************************************************************************

    Typed cache class template. Stores items of a particular type.

    Template params:
        T = type of item to store in cache

*******************************************************************************/

class Cache ( T )
{
    /***************************************************************************

        Alias for an array of raw data the same size as the template type.

    ***************************************************************************/

    private alias ubyte[T.sizeof] RawValue;


    /***************************************************************************

        Raw data cache.

    ***************************************************************************/

    private Cache!(T.sizeof) cache;


    /***************************************************************************

        Constructor.

        Params:
            max_items = maximum number of items in the cache, set once, cannot
                be changed

    ***************************************************************************/

    public this ( size_t max_items )
    {
        this.cache = new Cache!(T.sizeof)(max_items);
    }


    /***************************************************************************

        Puts an item into the cahce. If the cache is full, the oldest item is
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

    public bool put ( hash_t key, time_t update_time, T value )
    {
        return this.cache.put(key, update_time, *cast(RawValue*)(&value));
    }


    /***************************************************************************

        Gets an item from the cahce. A pointer to the item is returned, if
        found. If the item exists in the cahce, its update time is updated.

        Params:
            key = key to lookup
            update_time = new update time to set for item

        Returns:
            pointer to item value, may be null if key not found

    ***************************************************************************/

    public T* get ( hash_t key, lazy time_t update_time )
    {
        auto raw = this.cache.get(key, update_time);
        return cast(T*)raw;
    }


    /***************************************************************************

        Checks whether an item exists in the cahce.

        Params:
            key = key to lookup

        Returns:
            true if item exists in cache

    ***************************************************************************/

    public bool exists ( hash_t key )
    {
        return this.cache.exists(key);
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
        return this.cache.remove(key);
    }


    /***************************************************************************

        Removes all items from the cache.

    ***************************************************************************/

    public void clear ( )
    {
        this.cache.clear;
    }


    /***************************************************************************

        Returns:
            number of items in the cache

    ***************************************************************************/

    public size_t length ( )
    {
        return this.cache.length;
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
    
        struct Data
        {
            int x;
        }
    
        auto static_cache = new Cache!(Data)(2);
        assert(static_cache.length == 0);
    
        static_cache.put(1, time, Data(23));
        assert(static_cache.length == 1);
        assert(static_cache.exists(1));
        assert(static_cache.get(1, time).x == 23);
    
        static_cache.put(2, time + 1, Data(24));
        assert(static_cache.length == 2);
        assert(static_cache.exists(2));
        assert(static_cache.get(2, time + 1).x == 24);
    
        static_cache.put(2, time + 1, Data(25));
        assert(static_cache.length == 2);
        assert(static_cache.exists(2));
        assert(static_cache.get(2, time + 1).x == 25);
    
        static_cache.put(3, time + 2, Data(26));
        assert(static_cache.length == 2);
        assert(!static_cache.exists(1));
        assert(static_cache.exists(2));
        assert(static_cache.exists(3));
        assert(static_cache.get(3, time + 2).x == 26);
    
        static_cache.put(4, time + 3, Data(27));
        assert(static_cache.length == 2);
        assert(!static_cache.exists(1));
        assert(!static_cache.exists(2));
        assert(static_cache.exists(3));
        assert(static_cache.exists(4));
        assert(static_cache.get(4, time + 3).x == 27);
    
        static_cache.clear;
        assert(static_cache.length == 0);
    
        static_cache.put(1, time, Data(23));
        assert(static_cache.length == 1);
        assert(static_cache.exists(1));
        assert(static_cache.get(1, time).x == 23);
    
        static_cache.put(2, time + 1, Data(24));
        assert(static_cache.length == 2);
        assert(static_cache.exists(2));
        assert(static_cache.get(2, time + 1).x == 24);
    
        static_cache.remove(1);
        assert(static_cache.length == 1);
        assert(!static_cache.exists(1));
        assert(static_cache.exists(2));
    
    
        // ---------------------------------------------------------------------
        // Test of dynamic sized cache
    
        ubyte[] data1 = cast(ubyte[])"hello world";
        ubyte[] data2 = cast(ubyte[])"goodbye world";
        ubyte[] data3 = cast(ubyte[])"hallo welt";
    
        auto dynamic_cache = new Cache!()(2);
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

//TODO: performance test -- speed of put & get
debug ( OceanPerformanceTest )
{
    unittest
    {
    }
}

