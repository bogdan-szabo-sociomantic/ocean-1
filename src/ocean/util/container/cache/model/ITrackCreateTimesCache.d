/*******************************************************************************

    Extends ICache by tracking the creation time of each cache element.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt

*******************************************************************************/

module ocean.util.container.cache.model.ITrackCreateTimesCache;

import ocean.util.container.cache.model.ICache;

import tango.stdc.time: time_t;

/******************************************************************************/

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
