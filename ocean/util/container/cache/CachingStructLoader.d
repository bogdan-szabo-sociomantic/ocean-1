/******************************************************************************

    Wraps a cache for struct values. When a record cannot be found in the
    cache, an abstract method is called to look up the record in an external
    source.
    
    Copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    Version:        July 2011: Initial release
    
    Authors:        David Eckardt
    
 ******************************************************************************/

module ocean.util.container.cache.CachingStructLoader;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.util.container.cache.CachingDataLoader;

private import ocean.io.serialize.StructLoader;

private import tango.stdc.time: time_t;

debug (DhtDynamicCache) private import tango.io.Stdout;

/******************************************************************************/

class CachingStructLoader ( S ) : CachingDataLoader
{
    /**************************************************************************

        Constructor
        
        Params:
            cache          = cache to use
            bytes_reserved = minimum buffer size for preallocation, will be
                             rounded up to Struct.sizeof.
        
     **************************************************************************/

    public this ( Cache cache, size_t bytes_reserved = 0 )
    {
        super(cache, new BufferedStructLoader!(S)(bytes_reserved));
    }
    
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
        void[] data = this.load(key);
        
        return data.length? cast (S*) data[0 .. S.sizeof].ptr : null;
    }
}
