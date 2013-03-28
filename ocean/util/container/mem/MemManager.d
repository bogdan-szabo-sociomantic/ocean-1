/*******************************************************************************

    Interface and GC / malloc implementations of a memory manager which can
    create and destroy chunks of memory.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman, Mathias Baumann

*******************************************************************************/

module ocean.util.container.mem.MemManager;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Exception;

private import tango.core.Exception : OutOfMemoryException;

private import tango.stdc.stdlib : malloc, free;

/*******************************************************************************

    C Malloc memory manager instance

*******************************************************************************/

const IMemManager mallocMemManager;

/*******************************************************************************

    GC memory manager instance

*******************************************************************************/

const IMemManager gcMemManager;

static this ( )
{
    mallocMemManager = new MallocMemManager;
    gcMemManager = new GCMemManager;
}

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

        Explicit deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void destroy ( ubyte[] buffer );


    /***************************************************************************

        Dispose compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        void Object.dispose() is called on explicit delete. This method is
        intended to be called from that method.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void dispose ( ubyte[] buffer );


    /***************************************************************************

        Destructor compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        The destructor is always called when an object is collected or when it
        is explicitly deleted. This method is intended to be called from the
        destructor.

        Params:
            buffer = buffer to cleanup

    ***************************************************************************/

    public void dtor ( ubyte[] buffer );
}



/*******************************************************************************

    Memory manager implementation using the D garbage collector.

*******************************************************************************/

private class GCMemManager : IMemManager
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

        Explicit deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void destroy ( ubyte[] buffer )
    {
        delete buffer;
    }


    /***************************************************************************

        Deallocates the passed buffer.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void dispose ( ubyte[] buffer )
    {
        delete buffer;
    }


    /***************************************************************************

        Destructor compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        The destructor is always called when an object is collected or when it
        is explicitly deleted. This method is intended to be called from the
        destructor.

        Params:
            buffer = buffer to cleanup

    ***************************************************************************/

    public void dtor ( ubyte[] buffer )
    {
    }
}



/*******************************************************************************

    Memory manager implementation using malloc and free.

*******************************************************************************/

private class MallocMemManager : IMemManager
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

        Explicit deallocation

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


    /***************************************************************************

        Does nothing.

        Params:
            buffer = buffer to deallocate

    ***************************************************************************/

    public void dispose ( ubyte[] buffer )
    {
    }


    /***************************************************************************

        Destructor compatible deallocation

        Note that it is up to the user of classes which implement this interface
        to ensure that the buffer passed was in fact allocated by the same
        instance.

        The destructor is always called when an object is collected or when it
        is explicitly deleted. This method is intended to be called from the
        destructor.

        Params:
            buffer = buffer to cleanup

    ***************************************************************************/

    public void dtor ( ubyte[] buffer )
    {
        if ( buffer.ptr !is null )
        {
            free(buffer.ptr);
        }
    }
}

