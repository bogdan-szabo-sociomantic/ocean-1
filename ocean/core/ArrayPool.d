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

    ArrayPool is simple a wrapper around the Pool class, with the addition of
    the add() method, for convenience. Pool is designed to be safe to use in an
    ObjectPool (for lists of lists of items), having a reset method, called by
    recycle, which clears all items in the pool. Thus, ArrayPool can be safely
    used for a list of lists of arrays.

*******************************************************************************/

module ocean.core.ArrayPool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array : copy;

private import ocean.core.Pool;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Array pool class.

    Template params:
        T = type of array element

*******************************************************************************/

deprecated class ArrayPool ( T ) : Pool!(T[])
{
    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ( )
    {
        super();
    }


    /***************************************************************************

        Adds an array to the pool. The array's contents are copied into the
        pool.

        Params:
            array = array to add

        Returns:
            array that was added

    ***************************************************************************/
    
    public T[]* add ( T[] array )
    {
        auto new_array = super.get;
        (*new_array).copy(array);

        return new_array;
    }
}

