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
    
        Returns:
            the maximum number of items the cache can have.
    
    ***************************************************************************/
    
    public size_t max_length ( );
    
    /***************************************************************************
    
        Returns:
            the number of items currently in the cache.
    
    ***************************************************************************/
    
    public size_t length ( );
    
    /***************************************************************************
    
        Returns:
            the number of cache lookups since instantiation or the last call of
            resetStats().
    
    ***************************************************************************/
    
    uint num_lookups ( );
    
    /***************************************************************************
    
        Returns:
            the number of cache lookups since instantiation or the last call of
            resetStats() where the element could not be found.
    
    ***************************************************************************/
    
    uint num_misses  ( );
    
    /***************************************************************************
    
        Resets the statistics counter values.
    
    ***************************************************************************/
    
    void resetStats ( );
}
