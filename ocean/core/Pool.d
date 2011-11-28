/*******************************************************************************

    Manages a pool of value types

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    TODO: with the new ObjectPool, this will probably be deprecated, along with
    ArrayPool. Its use of pointers to index items in the pool is probably
    faulty.

*******************************************************************************/

module ocean.core.Pool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ObjectPool;

private import ocean.core.ArrayMap;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Pool item class template.

    Template params:
        T = type of data to store in pool

*******************************************************************************/

private class Item ( T )
{
    T data;
}



/*******************************************************************************

    Pool class template.

    Template params:
        T = type of data to store in pool

*******************************************************************************/

deprecated public class Pool ( T ) : Resettable
{
    /***************************************************************************

        This alias

    ***************************************************************************/

    private alias typeof(this) This;


    /***************************************************************************

        Alias for the type of a pool item

    ***************************************************************************/

    private alias Item!(T) ItemType;


    /***************************************************************************

        Internal object pool

    ***************************************************************************/

    private alias ObjectPool!(ItemType) ObjPool;

    private ObjPool pool;


    /***************************************************************************

        Internal array map, mapping from a pointer to an item to the object in
        the pool.

    ***************************************************************************/

    private alias ArrayMap!(ItemType, T*) ObjMap;

    private ObjMap map;


    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( )
    {
        this.pool = new ObjPool;
        this.map = new ObjMap;
    }


    /***************************************************************************

        Gets an item from the pool.

        Returns:
            pointer to item

    ***************************************************************************/

    public T* get ( )
    {
        auto item = this.pool.get();

        auto data = &item.data;
        this.map[data] = item;

        return data;
    }


    /***************************************************************************

        Recycles a pool item.
        
        Params:
            data = pointer to item to recycle

        Returns:
            this

    ***************************************************************************/

    public This recycle ( T* data )
    {
        auto item = data in this.map;

        if ( item !is null )
        {
            this.pool.recycle(*item);
        }

        return this;
    }


    /***************************************************************************

        Clears the pool, recycling all items.

        Returns:
            this

    ***************************************************************************/

    public This clear ( )
    {
        this.pool.clear;
        this.map.clear;

        return this;
    }


    /***************************************************************************

        Reset method, called by ObjectPool.recycle_(). Allows ObjectPools of
        Pools to be created.

    ***************************************************************************/

    public void reset ( )
    {
        this.clear;
    }


    /***************************************************************************

        Returns:
            number of items in the pool (including both busy and idle items)

    ***************************************************************************/

    public size_t getNumItems ( )
    {
        return this.pool.length;
    }


    /***************************************************************************

        Returns:
            number of busy items in the pool

        Note: aliased as length

    ***************************************************************************/

    public size_t getNumBusyItems ( )
    {
        return this.pool.num_busy;
    }

    public alias getNumBusyItems length;
    

    /***************************************************************************

        Returns:
            number of idle items in the pool

    ***************************************************************************/

    public size_t getNumIdleItems ( )
    {
        return this.pool.num_idle;
    }


    /***************************************************************************

        foreach iterator over items in the pool.

    ***************************************************************************/

    public int opApply ( int delegate ( ref T* ) dg )
    {
        int ret;

        foreach ( item; this.pool )
        {
            T* data = &item.data;
            ret = dg(data);
            if ( ret )
            {
                break;
            }
        }

        return ret;
    }


    /***************************************************************************

        opIndex
        
        Params:
            index = index of pool item to get

        Returns:
            pointer to indexed pool item

    ***************************************************************************/

    public T* opIndex ( size_t index )
    in
    {
        assert(index < this.pool.length);
    }
    body
    {
        auto item = this.pool[index];
        return &item.data;
    }
}

