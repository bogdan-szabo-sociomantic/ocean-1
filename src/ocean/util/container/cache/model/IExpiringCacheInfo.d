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
}
