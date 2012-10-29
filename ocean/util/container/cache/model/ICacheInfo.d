/*******************************************************************************

    Cache info interface.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt
    
*******************************************************************************/

module ocean.util.container.cache.model.ICacheInfo;

interface ICacheInfo
{
    /***************************************************************************
    
        The cache size in (maximum number of items) as passed to constructor.
    
    ***************************************************************************/
    
    public size_t max_length ( );
    
    public size_t length ( );
}
