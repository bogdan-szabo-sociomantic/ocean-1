/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, Mathias Baumann, David Eckardt

    Class templates for reusable buffers with minimal memory allocation.

    Each class has its own detailed description and usage example below.

*******************************************************************************/

module ocean.core.ConcatBuffer;



/*******************************************************************************

    Concat buffer class template.

    Template params:
        T = element type of buffer

    This template is useful for situations where you want to be able to
    repeatedly fill and empty a buffer of type T[] without recurring memory
    allocation. The buffer will grow over time to the required maximum size, and
    then will no longer allocate memory.

    ConcatBuffer classes also avoid modifying the .length property of the
    internal buffer, which has been observed to be costly, even when extending
    an array's length to <= its previous length.

    Internally the class stores a single buffer. If an item is added which does
    not fit in the currently allocated buffer, then a new expanded buffer is
    newed and replaces the old buffer. This means that the old buffer still
    exists in memory, and will not be garbage collected until here are no more
    references to it. As a result of this behaviour, any slices remaining to the
    previous buffer may still safely be used. Only at the point where all these
    slices no longer reference the old buffer will it be garbage collected.

    Usage example:

    ---

        import ocean.core.ConcatBuffer;

        // Create a concat buffer
        auto buff = new ConcatBuffer!(char);

        // Repeatedly...
        while ( application_running )
        {
            // Empty the buffer
            buff.clear();

            // Add stuff to the buffer
            buff.add("hello");
            buff.add("world");
        }

    ---

*******************************************************************************/

public class ConcatBuffer ( T )
{
    /***************************************************************************

        Data buffer.

    ***************************************************************************/

    private T[] buffer;

    
    /***************************************************************************

        Current write position in the buffer.

    ***************************************************************************/

    private size_t write_pos;

 
    /***************************************************************************

        Constructor.
        
        Params:
            len = initial buffer length

    ***************************************************************************/

    public this ( size_t len = 0 )
    {
        this.buffer.length = len;
    }


    /***************************************************************************

        Appends a new piece of data to the end of the buffer.

        Params:
            data = data to append to buffer

        Returns:
            in-place slice to the location in the buffer where the new item was
            appended

    ***************************************************************************/

    public T[] add ( T[] data )
    {
        return this.add(data.length)[] = data[];
    }
    
    
    /***************************************************************************

        Reserves a new piece of data at the end of the buffer.

        Params:
            length = amount of bytes to reserve

        Returns:
            in-place slice to the reserved data in the buffer

    ***************************************************************************/
    
    public T[] add ( size_t length ) 
    {
        if ( this.write_pos + length > this.buffer.length )
        {
            this.buffer = new T[this.buffer.length + length];
            this.write_pos = 0;
        }

        auto start = this.write_pos;
        auto end = start + length;

        this.write_pos = end;

        return this.buffer[start .. end];
    }
    

    /***************************************************************************

        Returns:
            the number of elements which the currently allocated buffer can
            contain

    ***************************************************************************/

    public size_t dimension ( )
    {
        return this.buffer.length;
    }


    /***************************************************************************

        Empties the buffer.

    ***************************************************************************/

    public void clear ( )
    {
        this.write_pos = 0;
    }
}



/*******************************************************************************

    Slice buffer class template. Extends ConcatBuffer, encapsulating a buffer
    with a list of slices to the concatenated items.

    Template params:
        T = element type of buffer

    This template is useful for situations where you need to build up a list of
    arrays of type T[], and be able to repeatedly fill and empty the list
    without recurring memory allocation. Note that once an item is added to the
    buffer, it is *not* possible to modify its length, as each item is only
    stored as a slice (though it is possible to modify the contents of a slice).
    (For situations where you want to be able to modify the lengths of the
    individual arrays after adding them to the collection, a Pool of structs
    containing arrays would be a suitable solution -- see
    ocean.core.ObjectPool.)

    Usage example:

    ---

        import ocean.core.ConcatBuffer;

        // Create a slice buffer
        auto buff = new SliceBuffer!(char);

        // Repeatedly...
        while ( application_running )
        {
            // Empty the buffer
            buff.clear();

            // Add stuff to the buffer
            buff.add("hello");
            buff.add("world");

            // Iterate over the items in the buffer
            foreach ( index, item; buff )
            {
            }
        }

    ---

*******************************************************************************/

public class SliceBuffer ( T ) : ConcatBuffer!(T)
{
    /***************************************************************************

        List of slices into the buffer content. A slice is added to the list
        each time an item is added to the buffer.

    ***************************************************************************/

    private T[][] slices;


    /***************************************************************************

        Constructor.

        Params:
            len = initial buffer length

    ***************************************************************************/

    public this ( size_t len = 0 )
    {
        super(len);
    }


    /***************************************************************************

        Appends a new piece of data to the end of the buffer. The item is also
        added to the slices list.

        Params:
            data = data to append to buffer

        Returns:
            in-place slice to the location in the buffer where the new item was
            appended

    ***************************************************************************/

    override public T[] add ( T[] data )
    {
        auto slice = super.add(data);
        this.slices ~= slice;
        return slice;
    }


    /***************************************************************************

        Empties the buffer.

    ***************************************************************************/

    override public void clear ( )
    {
        super.clear;
        this.slices.length = 0;
    }


    /***************************************************************************

        Returns:
            the number of items added to the buffer

    ***************************************************************************/

    public size_t length ( )
    {
        return this.slices.length;
    }


    /***************************************************************************

        Gets an indexed item in the items list.

        Params:
            index = index of item to get

        Returns:
            indexed item

        Throws:
            out of bounds exception if index is > the number of items added to
            the buffer

    ***************************************************************************/

    public T[] opIndex ( size_t index )
    {
        return this.slices[index];
    }


    /***************************************************************************

        foreach iterator over the items which have been added to the buffer.

    ***************************************************************************/

    public int opApply ( int delegate ( ref T[] ) dg )
    {
        int res;

        foreach ( slice; this.slices )
        {
            res = dg(slice);

            if ( res ) break;
        }

        return res;
    }


    /***************************************************************************

        foreach iterator over the items which have been added to the buffer and
        their indices.

    ***************************************************************************/

    public int opApply ( int delegate ( ref size_t, ref T[] ) dg )
    {
        int res;
    
        foreach ( i, slice; this.slices )
        {
            res = dg(i, slice);
    
            if ( res ) break;
        }
    
        return res;
    }
}


