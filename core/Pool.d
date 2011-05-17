/*******************************************************************************

    Manages a pool of value types

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    TODO: description, usage example, method comments

*******************************************************************************/

module ocean.core.Pool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ObjectPool;

private import ocean.core.ArrayMap;

debug private import tango.util.log.Trace;



private class Item ( T )
{
    T data;
}

public class Pool ( T ) : Resettable
{
    private alias typeof(this) This;

    private alias Item!(T) ItemType;
    
    private alias ObjectPool!(ItemType) ObjPool;
    private ObjPool pool;

    private alias ArrayMap!(ItemType, T*) ObjMap;
    private ObjMap map;

    public this ( )
    {
        this.pool = new ObjPool;
        this.map = new ObjMap;
    }

    public T* get ( )
    {
        auto item = this.pool.get();

        auto data = &item.data;
        this.map[data] = item;

        return data;
    }

    public This recycle ( T* data )
    {
        auto item = data in this.map;

        if ( item !is null )
        {
            this.pool.recycle(*item);
        }

        return this;
    }

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

    public size_t getNumItems ( )
    {
        return this.pool.getNumItems;
    }

    public size_t getNumBusyItems ( )
    {
        return this.pool.getNumBusyItems;
    }

    public alias getNumBusyItems length;
    
    public size_t getNumIdleItems ( )
    {
        return this.pool.getNumIdleItems;
    }

    public This remove ( T* data )
    {
        auto item = data in this.map;

        if ( item !is null )
        {
            this.pool.remove(*item);
            this.map.remove(data);
        }

        return this;
    }

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

    public T* opIndex ( size_t index )
    in
    {
        assert(index < this.pool.getNumItems);
    }
    body
    {
        auto item = this.pool[index];
        return &item.data;
    }
}

