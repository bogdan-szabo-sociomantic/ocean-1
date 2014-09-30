/******************************************************************************

    Wraps a cache for struct values. When a record cannot be found in the
    cache, an abstract method is called to look up the record in an external
    source.

    Copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.container.cache.CachingStructLoader;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.cache.ExpiringCache,
               ocean.util.container.cache.model.IExpiringCacheInfo;
private import CacheValue = ocean.util.container.cache.model.Value;

private import ocean.util.serialize.contiguous.package_;

private import tango.stdc.time: time_t, time;

/*******************************************************************************

    Base class for a cache. To use it you need to inherit it and override
    `getData` method. It operates only on contiguous struct buffers and does
    a copy of such buffer before returning cache element.

    Recommended code pattern is to have a shared Cache but a fiber-local
    CachingStructLoader so that last accessed element won't become invalidated
    between context switches

    Template Params:
        S = type of the deserialized struct expected in contiguous buffer

*******************************************************************************/

class CachingStructLoader ( S )
{
    /***************************************************************************

        The struct of data stored in the cache. It bundles the value to store
        with a "pending" flag which is true for newly created cache element
        where the value has not been filled in yet to detect and handle a race
        condition of load().

        In the future this "pending" flag might be replaced with a list of
        objects that allow reentrant load() calls with the same key to wait
        until the value has arrived.

    ***************************************************************************/

    private struct CacheValue
    {
        /***********************************************************************

            The value to store.
            "alias value this" would be nice.

        ***********************************************************************/

        mixin .CacheValue.Value!(0);
        Value value;

        /***********************************************************************

            The "pending" flag.

        ***********************************************************************/

        bool pending;

        /***********************************************************************

            Casts a reference to a cache value as obtained from get/createRaw()
            to a pointer to an instance of this struct.

            Params:
                data = data of an instance of this struct

            Returns:
                a pointer to an instance of this struct referencing data;
                i.e. cast(typeof(this))data.ptr.

            In:
                data.length must match the size of this struct.

         **********************************************************************/

        static typeof(this) opCall ( void[] data )
        in
        {
            assert (data.length == typeof(*this).sizeof);
        }
        body
        {
            return cast(typeof(this))data.ptr;
        }
    }

    /**************************************************************************

        The cache class. We need to enable GC scanning of the values stored in
        the cache because they contain references.

    ***************************************************************************/

    public static class Cache : ExpiringCache!(CacheValue.sizeof)
    {
        /***********************************************************************

            Constructor.

            Params:
                max_items = maximum number of items in the cache, set once,
                            cannot be changed
                lifetime  = life time for all items in seconds; may be changed
                            at any time. This value must be at least 1.

        ***********************************************************************/

        public this ( size_t max_items, time_t lifetime )
        {
            super(max_items, lifetime);
            this.enableGcValueScanning();
        }
    }

    /**************************************************************************

        DhtDynamic cache_ instance

    ***************************************************************************/

    private Cache cache_;

    /**************************************************************************

        Cached element is copied in this buffer before being returned. If
        fiber-local instances of CachingStructLoader are used this will
        guarantee that all pointers remain good between context switches.

    ***************************************************************************/

    private Contiguous!(S) fiber_local_copy;

    /**************************************************************************

        Flag to determine whether empty values returned by the value getter
        delegate passed to load() are added to the cache or not.

        It is supposed to be set in derivative cache classes depending on
        desired behaviour.

    ***************************************************************************/

    protected bool add_empty_values = true;

    /**************************************************************************

        Info interface for the cache instance is exposed to the public.

    ***************************************************************************/

    public IExpiringCacheInfo cache;

    /**************************************************************************

        Constructor

        Params:
            cache_ = cache to use

     **************************************************************************/

    public this ( Cache cache_ )
    {
        this.cache = this.cache_ = cache_;
    }

    /**************************************************************************

        Copies contiguous struct data into cache slot. Deletes the cache
        entry on deserialization error. Data can contain 0-length buffer.

        After that copies that data once again to this.fiber_local_copy and
        returns it. `this.fiber_local_copy.length == 0` will indicate that
        empty value was stored

        Params:
            key  = cache element key
            data = data to store in the cache
            cache_slot = cache slot to store copy data to

        Returns:
            this.fiber_local_copy

        Throws:
            StructLoaderException on error deserializing data.

    ***************************************************************************/

    private Contiguous!(S) store ( hash_t key, Contiguous!(S) data, ref CacheValue.Value cache_slot )
    {
        scope (failure) this.cache_.remove(key);

        /* Unfourtunately there is no way to define CacheValue that stores
         * Contiguous!(S) inside and `copy` function needs access to that cache
         * slot buffer by reference to be able to resize it.
         *
         * This is a cheap workaround that uses the fact that array and struct
         * that contains single array field have identical binary layout : get
         * pointer to internal void[] buffer and reinterpret cast it as if it
         * was Contiguous!(S) buffer. All resizes done from `copy` will then be
         * done directly on cache slot.
         */
        auto dst = cast(Contiguous!(S)*) cast(void[]*) cache_slot;

        if (data.length)
        {
            // storing shared cache value
            .copy(data, *dst);
            // storing fiber-local copy of same value that will be returned
            // to application code
            .copy(data, this.fiber_local_copy);
        }
        else
        {
            // storing empty value (cache miss)
            cache_slot[] = null;
            this.fiber_local_copy.reset();
        }

        return this.fiber_local_copy;
    }

    /**************************************************************************

        Loads/deserializes data if it is not null or empty.

        Params:
            data = data to load/deserialize. It must conform Contiguous!(S)
                requirements - only reason this method accepts void is because
                CacheValue can't store Contiguous!(S) preserving the type
                information.

        Returns:
            deseralized data or null of data was null or empty.

    ***************************************************************************/

    private Contiguous!(S) copy ( void[] data )
    {
        if (!data.length)
        {
            return this.fiber_local_copy.reset();
        }

        .copy(Contiguous!(S)(data), this.fiber_local_copy);
        return this.fiber_local_copy;
    }

    /**************************************************************************

        This method is called before storing new entry into the cache. It can
        be used to do any adjustments necessary for specific cached type. Does
        nothing by default which is most common case for exsting caches.

        If overriden this method must always modify data in-place

        Params:
            data = deserialized element data, use `data.ptr` to access it as S*

    ***************************************************************************/

    protected void onStoringData ( Contiguous!(S) data )
    {
    }

    /**************************************************************************

        Gets the record value corresponding to key. If it is not in the cache,
        this.getData is called with a callback delegate as argument. `getData`
        should then call the delegate passed to it with the obtained value. If
        `getData` found no value for key, it should return without calling the
        delegate.

        If the caller and `getData` use some sort of multitasking (fibers) it is
        possible that while get_data is busy it does a reentrant call of this
        method with the same key. In this case it will return null, even though
        the record may exist.

        Params:
            key = record key

        Returns:
            the record value or null if either not found or currently waiting
            for get_data to fetch the value for this key.

     **************************************************************************/

    protected Contiguous!(S) load ( hash_t key )
    {
        CacheValue* cached_value;
        bool value_is_cached = false;

        if (this.add_empty_values)
        {
            /*
             * If any value is stored in the map, even an empty value if the
             * element was not found in the external source, we can save a
             * lookup by using  getOrCreateRaw().
             */
            cached_value = CacheValue(this.cache_.getOrCreateRaw(key, value_is_cached));
        }
        else
        {
            auto value_or_null = this.cache_.getRaw(key);
            if (value_or_null !is null)
            {
                value_is_cached = true;
                cached_value = CacheValue(value_or_null);
            }
        }

        if (value_is_cached)
        {
            if (cached_value.pending)
            {
                // pretend data does not exist to prevent the fiber race
                return this.fiber_local_copy.reset();
            }

            return this.copy(cached_value.value[]);
        }

        // value wasn't cached, need to perform external data request

        this.fiber_local_copy.reset();

        if (!this.add_empty_values)
        {
            cached_value = CacheValue(this.cache_.createRaw(key));
            // .. for other case value is aready created because of `getOrCreateRaw`
        }

        cached_value.pending = true;

        this.getData(
            key,
            (Contiguous!(S) data)
            {
                if (data.length || this.add_empty_values)
                {
                    this.onStoringData(data);
                    this.store(key, data, cached_value.value);
                    cached_value.pending = false;
                }
            }
        );

        if (cached_value.pending && !this.add_empty_values)
        {
            this.cache_.remove(key);
        }

        return this.fiber_local_copy;
    }


    /**************************************************************************

        Looks up the record value corresponding to key and invokes got with that
        value if found. If not found, returns without calling got.

        Params:
            key = record key
            got = delegate to call back with the value if found

     **************************************************************************/

    abstract protected void getData ( hash_t key, void delegate ( Contiguous!(S) data ) got );

    /**************************************************************************

        Gets the record value corresponding to key.

        Params:
            key = key of the records to get

        Returns:
            Pointers to the record value corresponding to key or null if the
            record for key does not exist.

        Throws:
            Exception on data error

     **************************************************************************/

    public S* opIn_r ( hash_t key )
    {
        return this.load(key).ptr;
    }
}

unittest
{
    struct Dummy {}
    CachingStructLoader!(Dummy) loader;
}
