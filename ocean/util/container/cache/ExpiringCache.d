/*******************************************************************************

    Cache with an element expiration facility.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt
    
    Extends the Cache by providing a settable lifetime and automatically
    removing  elements where the difference between the current time and the
    createtime is greater than that lifetime value.
    
*******************************************************************************/

module ocean.util.container.cache.ExpiringCache;

private import ocean.util.container.cache.model.IExpiringCacheInfo;

private import ocean.util.container.cache.Cache;

private import tango.stdc.time: time_t;

/*******************************************************************************

    Data cache class template with element life time limitation. Stores items of
    raw data, either of fixed or dynamic size. When the life time of an item,
    which is the difference between its creation time and the current wall clock
    time, has expired, it is removed automatically on the next getRaw()/exists()
    access.
    
    Template params:
        ValueSize = size of a data item. If 0 is specified (the default), the
            items stored in the cache are of variable (dynamic) size

*******************************************************************************/

class ExpiringCache ( size_t ValueSize = 0 ) : Cache!(ValueSize, true),
                                               IExpiringCacheInfo
{
    /***************************************************************************
    
        Life time for all items in seconds; may be changed at any time.
        This value must be at least 1.
    
    ***************************************************************************/

    public time_t lifetime;
    
    /***************************************************************************
    
        Statistics counters 
    
    ***************************************************************************/

    private GetExpiredStats stats;
    
    /***************************************************************************

        Constructor.
    
        Params:
            max_items = maximum number of items in the cache, set once, cannot
                        be changed
            lifetime  = life time for all items in seconds; may be changed at
                        any time. This value must be at least 1.
    
    ***************************************************************************/

    public this ( size_t max_items, time_t lifetime )
    in
    {
        assert (lifetime > 0, "cache element lifetime is expected to be at "
                              "least 1");
    }
    body
    {
        super(max_items);
        
        this.lifetime = lifetime;
    }
    
    /***************************************************************************

        Gets an item from the cache. If the item was found in the cache, its
        access time is updated. If the item life time has expired, it is
        automatically removed.
    
        Note that, if you change the value referenced by the returned reference,
        the create time will not be updated.

        Params:
            key = key to lookup

        Returns:
            a reference to the item value or null if no such item was found or
            it has expired so it was removed.

        Out:
            See super class.

    ***************************************************************************/
    
    public override ValueRef getRaw ( hash_t key )
    {
        bool existed;
        
        return this.getExpiringOrCreate(key, existed);
    }
    
    /***************************************************************************

        Gets an item from the cache. If the item was found in the cache, its
        access time is updated. If the item life time has expired, it is
        automatically removed.
    
        Note that, if you change the value referenced by the returned reference,
        the create time will not be updated.

        Params:
            key     = key to lookup
            expired = true:  the item was found but expired so it was removed,
                      false: the item was not found 
                      
        Returns:
            a reference to the item value or null if no such item was found or
            it has expired so it was removed.
        
        Out:
            - If expired, the returned reference is null.
            - See super class.

    ***************************************************************************/
    
    public ValueRef getRaw ( hash_t key, out bool expired )
    out (val)
    {
        if (expired) assert (val is null);
    }
    body
    {
        bool existed;
        
        ValueRef val = this.getExpiringOrCreate(key, existed);
        
        expired = !val && existed;
        
        return val;
    }
    
    /***************************************************************************

        Gets an item from the cache or creates it if not already existing. If
        the item was found in the cache, its access time is updated, otherwise
        its create time is set. If the item was found but was expired, the
        effect is the same as if the item was not found.
        
        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        reference.
        
        Params:
            key     = key to lookup
            existed = true:  the item already existed,
                      false: the item was created either because it did not
                             exist or was expired
        
        Returns:
            a reference to the value of the obtained or created item. If an old
            item was replaced, this reference refers to the old value. 
    
        Out:
            See super class.
        
    ***************************************************************************/
    
    public override ValueRef getOrCreateRaw ( hash_t key, out bool existed )
    {
        return this.getExpiringOrCreate(key, existed, true);
    }
    
    /***************************************************************************

        Checks whether an item exists in the cache and updates its access time.
        If the life time of the item has expired, it is removed.
    
        Params:
            key     = key to lookup
            expired = true: an item was found but removed because it was expired
    
        Returns:
            true if item exists in cache and its life time is not yet expired.
        
        Out:
            If expired is false, the return value is false.
        
    ***************************************************************************/

    public bool exists ( hash_t key, out bool expired )
    out (does_exist)
    {
        if (expired) assert (!does_exist);
    }
    body
    {
        return this.getRaw(key, expired) !is null;
    }
    
    /***************************************************************************

        Checks whether an item exists in the cache and updates its access time.
        If the life time of the item has expired, it is removed.
    
        Params:
            key = key to lookup
    
        Returns:
            true if item exists in cache and its life time is not yet expired.
    
    ***************************************************************************/
    
    public override bool exists ( hash_t key )
    {
        bool expired;
        
        return this.exists(key, expired);
    }
    
    /***************************************************************************
    
        Obtains the statistics counters for getRaw()/exists() calls, caches
        misses and expired elements. 
        
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

        Gets an item from the cache or optionally creates it if not already
        existing. If the item was found in the cache, its access time is
        updated, otherwise its create time is set. If the item was found but was
        expired, the effect is the same as if the item was not found.
        
        Note that the create time is set only if an item is created, not if it
        already existed and you change the value referenced by the returned
        reference.
        
        Params:
            key     = key to lookup
            existed = true:  the item already existed,
                      false: the item did not exist or was expired
            create  = true: create the item if it doesn't exist or is expired
        
        Returns:
            a reference to the value of the obtained or created item. If an old
            item was replaced, this reference refers to the old value. 
    
        Out:
            - If create is true, the returned reference is not null.
            - If create and existed are false, the returned reference is null.
        
    ***************************************************************************/
    
    private ValueRef getExpiringOrCreate ( hash_t key, out bool existed,
                                           bool create = false )
    in
    {
        assert (this.lifetime > 0, "cache element lifetime is expected to be "
                                   "at least 1");
    }
    out (val)
    {
        if (create)
        {
            assert (val !is null);
        }
        else if (!existed)
        {
            assert (val is null);
        }
    }
    body
    {
        TimeToIndex.Node** node = key in this;
        
        // opIn_r may return null but never a pointer to null.
        
        CacheItem* cache_item = null;
        
        existed = node !is null;
        
        if (existed)
        {
            time_t access_time;
            
            cache_item = this.access(**node, access_time);
            
            // access() will never return null.
            
            if (access_time >= cache_item.create_time)
            {
                /*
                 * We silently tolerate the case the element was created after
                 * its last access because with the system time as external
                 * data source this is theoretically possible and at least no
                 * program bug.
                 */
                
                existed = (access_time - cache_item.create_time) < this.lifetime;
            }
            
            if (!existed)
            {
                if (create)
                {
                    cache_item.create_time = access_time;
                }
                else
                {
                    this.remove_(key, **node);
                    cache_item = null;
                }
                  
                this.stats.expired++;
                this.stats.misses++;
            }
        }
        else
        {
            if (create)
            {
                time_t access_time;
                
                cache_item = this.add(key, access_time);
                
                cache_item.create_time = access_time;
            }
            
            this.stats.misses++;
        }
        
        this.stats.total++;
        
        return cache_item? cache_item.value_ref : null;
    }
}

/******************************************************************************/

import tango.stdc.posix.stdlib: srand48, mrand48, drand48;
import tango.stdc.time: time;

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
    // Test of expiring cache
    
    {
        char[] data1 = "hello world",
               data2 = "goodbye world",
               data3 = "hallo welt";
        
        time_t t = 0;
        
        scope expiring_cache = new class ExpiringCache!()
        {
            this ( ) {super(4, 10);}
            
            override time_t now ( ) {return ++t;}
        };
        
        with (expiring_cache)
        {
            assert(length == 0);
        
            *createRaw(1) = data1;
            assert(length == 1);
            assert(exists(1));
            {
                Value* data = getRaw(1);
                assert(data !is null);
                assert((*data)[] == data1);
            }
            
            assert(t <= 5);
            t = 5;
            
            *createRaw(2) = data2;
            assert(length == 2);
            assert(exists(2));
            {
                Value* data = getRaw(2);
                assert(data !is null);
                assert((*data)[] == data2);
            }
            
            assert(t <= 10);
            t = 10;
            
            assert(!exists(1));
            
            assert(t <= 17);
            t = 17;
            
            {
                Value* data = getRaw(2);
                assert(data is null);
            }
        }
    }
    
}
