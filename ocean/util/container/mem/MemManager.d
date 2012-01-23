/*******************************************************************************

    Interface and GC / malloc implementations of a memory manager which can
    create and destroy chunks of memory.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        June 2012: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.util.container.mem.MemManager;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Exception;

private import tango.core.Exception : OutOfMemoryException;

private import tango.stdc.stdlib : malloc, free;



/*******************************************************************************

    Memory manager interface.

*******************************************************************************/

public interface IMemManager
{
    /***************************************************************************

        Allocates a buffer of the specified dimension.

        Params:
            dimension = bytes to allocate

        Returns:
            new buffer

    ***************************************************************************/

    public ubyte[] create ( size_t dimension );


    /***************************************************************************

        Deallocates the passed buffer.

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void destroy ( ubyte[] buffer );
}



/*******************************************************************************

    Memory manager implementation using the D garbage collector.

*******************************************************************************/

public class GCMemManager : IMemManager
{
    /***************************************************************************

        Allocates a buffer of the specified dimension via the GC.

        Params:
            dimension = bytes to allocate

        Returns:
            new buffer

    ***************************************************************************/

    public ubyte[] create ( size_t dimension )
    {
        return new ubyte[dimension];
    }


    /***************************************************************************

        Deallocates the passed buffer.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void destroy ( ubyte[] buffer )
    {
        delete buffer;
    }
}



/*******************************************************************************

    Memory manager implementation using malloc and free.

*******************************************************************************/

public class MallocMemManager : IMemManager
{
    /***************************************************************************

        Allocates a buffer of the specified dimension using malloc.

        Params:
            dimension = bytes to allocate

        Returns:
            new buffer

    ***************************************************************************/

    public ubyte[] create ( size_t dimension )
    {
        auto ptr = cast(ubyte*)malloc(dimension);
        assertEx(ptr !is null, new OutOfMemoryException(__FILE__, __LINE__));

        return ptr[0..dimension];
    }


    /***************************************************************************

        Deallocates the passed buffer using free.

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void destroy ( ubyte[] buffer )
    {
        if ( buffer.ptr !is null )
        {
            free(buffer.ptr);
        }
    }
}

