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

private import ocean.io.serialize.StructLoader: IBufferedStructLoader;

private import tango.stdc.time: time_t, time;

/******************************************************************************/

abstract class CachingDataLoaderBase
{
    /**************************************************************************
    
        Cache alias type definition
    
     **************************************************************************/
    
    public alias ExpiringCache!(0) Cache;
    
    /**************************************************************************
    
        Cache instance, an info interface is exposed to the public.
    
     **************************************************************************/
    
    public const IExpiringCacheInfo cache;
    
    private const Cache cache_;
    
    /**************************************************************************

        DhtDynamic cache_ instance
    
     **************************************************************************/
    
    private const IBufferedStructLoader loader;
    
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

    protected this ( Cache cache_, IBufferedStructLoader loader )
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

        Gets the record value corresponding to key. If it is not in the cache,
        get_data is called with a callback delegate as argument. get_data
        should then call the delegate passed to it with the obtained value. If
        get_data found no value for key, it should return without calling the
        delegate.
        
        Params:
            key      = record key
            get_data = callback delegate to obtain the value if not in the cache
        
        Returns:
            the record value or null if not found.
    
     **************************************************************************/
    
    protected void[] load ( hash_t key,
        void delegate ( void delegate ( void[] data ) got ) get_data )
    {
        auto value_in_cache = this.cache_.getRaw(key);
        
        if (value_in_cache)
        {
            return this.loadRaw((*value_in_cache)[]);
        }
        else
        {
            void[] value_out = null;

            get_data((void[] data)
                     {
                         if ( data || this.add_empty_values )
                         {
                             value_in_cache = this.cache_.createRaw(key);
                             value_out = this.loadRaw((*value_in_cache)[] = data[]);
                         }
                     });

            return value_out;
        }
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

 ******************************************************************************/

abstract class CachingDataLoader : CachingDataLoaderBase
{
    /**************************************************************************

        Constructor
        
        Params:
            cache_ = cache to use
            loader = struct loader to use
        
     **************************************************************************/

    protected this ( Cache cache, IBufferedStructLoader loader )
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
