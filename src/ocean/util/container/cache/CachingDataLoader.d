/*******************************************************************************

    Wraps a cache for values of variable size. When a record cannot be found in
    the cache, a delegate or abstract method is called to look up the record in
    an external source.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt

*******************************************************************************/

module ocean.util.container.cache.CachingDataLoader;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.util.container.cache.ExpiringCache;
private import ocean.util.container.cache.model.IExpiringCacheInfo;
private import CacheValue = ocean.util.container.cache.model.Value;

private import ocean.io.serialize.StructLoader: IBufferedStructLoader;

private import tango.stdc.time: time_t, time;

/*******************************************************************************

    Template Params:
        Loader = loader that should be used

*******************************************************************************/

abstract class CachingDataLoaderBase ( Loader )
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
            assert(data.length == typeof(*this).sizeof);
        }
        body
        {
            return cast(typeof(this))data.ptr;
        }
    }

    /**************************************************************************

        Cache alias type definition

     **************************************************************************/

    public alias ExpiringCache!(CacheValue.sizeof) Cache;

    /**************************************************************************

        Cache instance, an info interface is exposed to the public.

     **************************************************************************/

    public const IExpiringCacheInfo cache;

    private const Cache cache_;

    /**************************************************************************

        DhtDynamic cache_ instance

     **************************************************************************/

    private const IBufferedStructLoader!(Loader) loader;

    /**************************************************************************

        Flag to determine whether empty values returned by the value getter
        delegate passed to load() are added to the cache or not.

     **************************************************************************/

    public bool add_empty_values = true;

    /**************************************************************************

        Constructor

        Params:
            cache_ = cache to use
            loader = struct loader to use

     **************************************************************************/

    protected this ( Cache cache_, IBufferedStructLoader!(Loader) loader )
    {
        this.cache = this.cache_ = cache_;
        this.loader = loader;
    }

    /**************************************************************************

        Disposer

     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.loader;
    }

    /**************************************************************************

        Clears the loaded data.

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) clear ( )
    {
        this.loader.clear();
        return this;
    }

    /**************************************************************************

        This method is called before storing new entry into the cache. It can
        be used to do any adjustments necessary for specific cached type. Does
        nothing by default.

        If overriden this method must always modify data in-place

        Params:
            data = deserialized element data, can be cast directly to cached
                element pointer type

    ***************************************************************************/

    protected void onStoringData ( void[] data )
    {
    }

    /**************************************************************************

        Gets the record value corresponding to key. If it is not in the cache,
        get_data is called with a callback delegate as argument. get_data
        should then call the delegate passed to it with the obtained value. If
        get_data found no value for key, it should return without calling the
        delegate.

        If the caller and get_data use some sort of multitasking (fibers) it is
        possible that while get_data is busy it does a reentrant call of this
        method with the same key. In this case it will return null, even though
        the record may exist.

        Params:
            key      = record key
            get_data = callback delegate to obtain the value if not in the cache

        Returns:
            the record value or null if either not found or currently waiting
            for get_data to fetch the value for this key.

     **************************************************************************/

    protected void[] load ( hash_t key,
        void delegate ( void delegate ( void[] data ) got ) get_data )
    {
        if (this.add_empty_values)
        {
            /*
             * If any value is stored in the map, even an empty value if the
             * element was not found in the external source, we can save a
             * lookup by using  getOrCreateRaw().
             */

            bool existed;

            auto value_in_cache = CacheValue(this.cache_.getOrCreateRaw(key, existed));

            if (existed)
            {
                return value_in_cache.pending?
                    null:
                    this.loadRaw(value_in_cache.value[]);
            }
            else
            {
                void[] value_out = null;

                value_in_cache.pending = true;

                get_data((void[] data)
                         {
                             data = this.loadRaw(data);
                             this.onStoringData(data);
                             value_out = this.store(key, data, value_in_cache.value);
                             value_in_cache.pending = false;
                         });

                return value_out;
            }
        }
        else
        {

            if (auto value_or_null = this.cache_.getRaw(key))
            {
                auto value_in_cache = CacheValue(value_or_null);
                return value_in_cache.pending?
                    null:
                    this.loadRaw(value_in_cache.value[]);
            }
            else
            {
                void[] value_out = null;

                /*
                 * Reserve a cache entry to be able to detect reentrant calls
                 * with the same key and delete it if it couldn't be fetched
                 * from the external source. Assuming that get_data is usually
                 * able to fetch the requested records this shouldn't
                 * impact performance.
                 */

                auto value_in_cache = CacheValue(this.cache_.createRaw(key));

                value_in_cache.pending = true;

                get_data((void[] data)
                         {
                             if ( data.length )
                             {
                                 data = this.loadRaw(data);
                                 this.onStoringData(data);
                                 value_out = this.store(key, data, value_in_cache.value);
                                 value_in_cache.pending = false;
                             }
                         });

                if (value_in_cache.pending)
                {
                    this.cache_.remove(key);
                }

                return value_out;
            }
        }
    }

    /**************************************************************************

        Copies data into value_in_cache, then deserializes it. Deletes the cache
        entry on deserialization error.
        If, as in many use cases, data contains a serialized value of a type T
        that is not a dynamic array, the value can be obtained by casting the
        .ptr of the returned array to T*. (This pointer will be null if data is
        null or empty.)

        Params:
            key  = cache element key
            data = data to store in the cache and deserialize

        Returns:
            the deseralized data or null of data is null or empty.

        Throws:
            StructLoaderException on error deserializing data.

     **************************************************************************/

    private void[] store ( hash_t key, void[] data, ref CacheValue.Value value_in_cache )
    {
        scope (failure) this.cache_.remove(key);

        return this.loadRaw(value_in_cache[] = data[]);
    }

    /**************************************************************************

        Loads/deserializes data if it is not null or empty.

        Params:
            data = data to load/deserialize

        Returns:
            deseralized data or null of data was null or empty.

     **************************************************************************/

    private void[] loadRaw ( void[] data )
    {
        return data.length? this.loader.loadRaw(data) : null;
    }
}

/******************************************************************************

    Provides an abstract class method to obtain values instead of a callback
    delegate argument of load().

    Template Params:
        Loader = loader that should be used

 ******************************************************************************/

abstract class CachingDataLoader ( Loader ): CachingDataLoaderBase!(Loader)
{
    /**************************************************************************

        Constructor

        Params:
            cache_ = cache to use
            loader = struct loader to use

     **************************************************************************/

    protected this ( Cache cache, IBufferedStructLoader!(Loader) loader )
    {
        super(cache, loader);
    }

    /**************************************************************************

        Gets the record value corresponding to key.

        Params:
            key = record key

        Returns:
            the record value or null if not found.

     **************************************************************************/

    protected void[] load ( hash_t key )
    {
        return super.load(key, (void delegate ( void[] data ) got)
                               {this.getData(key, got);});
    }

    /**************************************************************************

        Looks up the record value corresponding to key and invokes got with that
        value if found. If not found, returns without calling got.

        Params:
            key = record key
            got = delegate to call back with the value if found

     **************************************************************************/

    abstract protected void getData ( hash_t key, void delegate ( void[] data ) got );
}
