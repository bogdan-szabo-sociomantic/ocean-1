/*******************************************************************************

    Interface to obtain cache statistics from an expiring cache.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt
    
*******************************************************************************/

module ocean.util.container.cache.model.IExpiringCacheInfo;

private import ocean.util.container.cache.model.ICacheInfo;

interface IExpiringCacheInfo : ICacheInfo
{
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
    
    GetExpiredStats get_remove_stats ( bool reset = false );
}

