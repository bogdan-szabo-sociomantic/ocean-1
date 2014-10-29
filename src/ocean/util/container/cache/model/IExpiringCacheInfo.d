/*******************************************************************************

    Interface to obtain cache statistics from an expiring cache.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt

*******************************************************************************/

module ocean.util.container.cache.model.IExpiringCacheInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.cache.model.ICacheInfo;

interface IExpiringCacheInfo : ICacheInfo
{
    /***************************************************************************

        Returns:
            the number of cache lookups  since instantiation or the last call of
            resetStats() where the element could be found but was expired.

    ***************************************************************************/

    uint num_expired ( );

    /***************************************************************************

        Please use num_expired() and ICacheInfo.num_lookups()/num_misses()/
        resetStats() instead.

        Statistics counters for get()/exists() calls, caches misses and expired
        elements.

    ***************************************************************************/

    deprecated struct GetExpiredStats
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

        Please use num_expired() and ICacheInfo.num_lookups()/num_misses()/
        resetStats() instead.

        Gets statistics information for get()/exists() calls, caches misses and
        expired elements.

        Params:
            reset = if true, the internal stats counters are reset to 0

        Returns:
            struct containing stats information

    ***************************************************************************/

    deprecated GetExpiredStats get_remove_stats ( bool reset = false );
}
