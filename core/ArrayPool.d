/*******************************************************************************

    Reusable pool of arrays.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    This class template is designed to avoid memory allocations every time an
    array of arrays is cleared (length set to 0) then refilled. For example, the
    following code, using a simple dynamic array of arrays, is unsafe, resulting
    in a memory allocation every time a string is added to the list:

    ---

        import ocean.core.Array : copy;

        // Array of arrays which we want to repeatedly re-use.
        char[][] strings;

        while ( true )
        {
            // Add some strings to the list
            for ( int i; i < 100; i++ )
            {
                strings.length = strings.length + 1;
                strings[$-1].copy("hello there");
            }

            // Remove all strings from the list.
            foreach ( ref s; strings )
            {
                s.length = 0;
            }
            strings.length = 0;
        }

    ---

    Using this template, an allocation-safe version of the above would be:

    ---

        scope strings = new ArrayPool!(char);

        while ( true )
        {
            // Add some strings to the list
            for ( int i; i < 100; i++ )
            {
                strings.add("hello there");
            }

            // Remove all strings from the list.
            strings.clear;
        }

    ---

    ArrayPool classes are also designed to be safe to use in an ObjectPool (for
    lists of lists of arrays), having a reset method, called by recycle, which
    clears all arrays in the pool.

    TODO: possibly move the Indexable stuff into ObjectPool...

*******************************************************************************/

module ocean.core.ArrayPool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.core.ArrayMap;

private import ocean.core.ObjectPool;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Class to be contained in an ObjectPool -- just stores an array.

    Template params:
        T = type of array element

*******************************************************************************/

private class ArrayObject ( T )
{
    T[] content;
}



/*******************************************************************************

    Array pool class.

    Template params:
        T = type of array element
        Indexable = boolean specifying whether an opIndex method is needed over
                    the array pool.

*******************************************************************************/

public class ArrayPool ( T, bool Indexable = true ) : Resettable
{
    /***************************************************************************

        Object pool of arrays.

    ***************************************************************************/

    private alias ObjectPool!(ArrayObject!(T)) Pool;

    private Pool pool;

    
    /***************************************************************************

        Optional array map, mapping from index -> array.

    ***************************************************************************/

    static if ( Indexable )
    {
        private alias ArrayMap!(Pool.PoolItem, size_t) PoolIndex;
    
        private PoolIndex pool_index;

        invariant ( )
        {
            assert(this.pool.getNumBusyItems == this.pool_index.length);
        }
    }


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        this.pool = new Pool;

        static if ( Indexable )
        {
            this.pool_index = new PoolIndex;
        }
    }


    /***************************************************************************

        Adds an array to the pool. The array's contents are copied into the
        pool.

        Params:
            array = array to add

    ***************************************************************************/

    public void add ( T[] array )
    {
        static if ( Indexable )
        {
            auto len = this.length;
        }

        auto new_array = this.pool.get;
        new_array.content.copy(array);

        static if ( Indexable )
        {
            this.pool_index.put(len, new_array);
        }
    }


    /***************************************************************************

        Returns:
            number of arrays in the pool

    ***************************************************************************/

    public size_t length ( )
    {
        return this.pool.getNumBusyItems;
    }


    /***************************************************************************

        Removes all arrays from the pool.

    ***************************************************************************/

    public void clear ( )
    {
        this.pool.clear;

        static if ( Indexable )
        {
            this.pool_index.clear;
        }
    }


    /***************************************************************************

        Reset method, called by ObjectPool.recycle_(). Allows ObjectPools of
        ArrayPools to be created.

    ***************************************************************************/

    public void reset ( )
    {
        this.clear;
    }


    /***************************************************************************

        Gets the nth array in the pool.

        Params:
            index = index of array to get

        Returns:
            nth array in pool

    ***************************************************************************/

    static if ( Indexable )
    {
        public T[] opIndex ( size_t index )
        in
        {
            assert(index < this.length, typeof(this).stringof ~ ".opIndex -- array index out of bounds");
        }
        body
        {
            return this.pool_index[index].content;
        }
    }


    /***************************************************************************

        foreach iterator over arrays in the pool.

    ***************************************************************************/

    public int opApply ( int delegate ( ref T[] ) dg )
    {
        int ret;
        foreach ( item; this.pool )
        {
            ret = dg(item.content);
            if ( ret )
            {
                break;
            }
        }

        return ret;
    }
}

