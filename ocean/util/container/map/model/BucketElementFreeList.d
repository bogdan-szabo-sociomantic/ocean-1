/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        06/07/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Free list of dynamically allocated objects of arbitrary type, a basic object
    pool.

*******************************************************************************/

module ocean.util.container.map.model.BucketElementFreeList;

/******************************************************************************/

private import ocean.core.Array: clear;

class FreeList
{
    /**************************************************************************

        List of free objects (e.g. struct instances).

     **************************************************************************/

    private void*[] free_list;

    /**************************************************************************

        Actual free_list length.

        The elements in free_list[n_free .. $] must be null to prevent dangling
        references, make it easier for the garbage collector and to allow for
        consistency checking. The elements in free_list[0 .. n_free] must be
        non-null because they refer to free objects.

     **************************************************************************/

    private size_t n_free;

    /**************************************************************************

        Consistency check.

     **************************************************************************/

    private bool parking_stack_open = false;

    /**************************************************************************

        Consistency check.

     **************************************************************************/

    invariant ( )
    {
        assert (this.n_free <= this.free_list.length);
        assert (!this.parking_stack_open, "attempted to use the outer " ~
                typeof (this).stringof ~ " instance of an existing " ~
                ParkingStack.stringof ~ " instance");
    }

    /**************************************************************************

        Constructor.

        Params:
            prealloc_length = initial free_list length for preallocation

     **************************************************************************/

    public this ( size_t prealloc_length = 0 )
    {
        this.free_list = new void*[prealloc_length];
    }

    /**************************************************************************

        Disposer.

     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.free_list;
        this.n_free = 0;
    }

    /**************************************************************************

        Obtains an object either from the free list, if available, or from
        new_object if the free list is empty.

        Params:
            new_object = expression returning a new object

        Returns:
            new object

        Out:
            The returned object cannot be null.

     **************************************************************************/

    public void* get ( lazy void* new_object )
    out (object)
    {
        assert (object !is null);
    }
    body
    {
        return this.n_free? this.get_(--this.n_free) : new_object;
    }

    /**************************************************************************

        Appends old_object to the free list.

        Params:
            old_object = object to recycle

        Returns:
            the recycled object, may safely be used until the next get() call.

        In:
            old_object must not be null.

     **************************************************************************/

    public void* recycle ( void* old_object )
    in
    {
        assert (old_object !is null);
    }
    body
    {
        return this.recycle_(old_object, this.n_free++);
    }

    /**************************************************************************

        Returns:
            the number of objects in the free list.

     **************************************************************************/

    public size_t length ( )
    {
        return this.n_free;
    }

    /**************************************************************************

        Sets the preallocated free list buffer length to n. n is rounded up to
        the current number of objects in the free list.

        Params:
            n = new preallocated free list buffer length

        Returns:
            the new free list which is the greater of n and the current number
            of objects in the free list.

     **************************************************************************/

    public size_t minimize ( size_t n = 0 )
    {
        if (n < this.n_free)
        {
            n = this.n_free;
        }

        if (this.free_list.length != n)
        {
            this.free_list.length = n;
        }

        return n;
    }

    /**************************************************************************

        Obtains free_list[n] and sets free_list[n] to null.

        Params:
            n = free list index

        Returns:
            free_list[n]

     **************************************************************************/

    private void* get_ ( size_t n )
    {
        scope (exit) this.free_list[n] = null;

        return this.free_list[n];
    }

    /**************************************************************************

        Appends object to the free list using n as insertion index. n is
        expected to refer to the position immediately after the last object in
        the free list, which may be free_list.length.

        Params:
            n = free list insertion index

        Returns:
            free_list[n]

     **************************************************************************/

    private void* recycle_ ( void* object, size_t n )
    in
    {
        if (n < this.free_list.length)
        {
            assert (this.free_list[n] is null, typeof (this).stringof ~ ": the "
                    "free list element after the list end must be null");

            if (n)
            {
                assert (this.free_list[n - 1] !is null, typeof (this).stringof ~
                        ": the last free list element must not be null");
            }
        }
        else
        {
            assert (n == this.free_list.length, typeof (this).stringof ~ ": "
                    "attempted to insert a gap when appending to the free list");
        }
    }
    body
    {
        if (n < this.free_list.length)
        {
            this.free_list[n] = object;
        }
        else
        {
            this.free_list ~= object;
        }

        return object;
    }

    /**************************************************************************

        Allows using the free list as a stack to park objects without marking
        them as free. The parked object are appended to the free list after the
        free objects currently in the list.
        At most one ParkingStack instance may exist at a time. While a
        ParkingStack instance exists, no public FreeList method may be used.

     **************************************************************************/

    scope class ParkingStack
    {
        /**********************************************************************

            Start and end index of the stack in the free list.

         **********************************************************************/

        private size_t start, end;

        /**********************************************************************

            Index consistency check.

         **********************************************************************/

        invariant ( )
        {
            assert (this.start <= this.end);
            assert (this.end   <= this.outer.free_list.length);
        }

        /**********************************************************************

            Constructor.

            Params:
                extent = expected stack length for preallocation, if known.

         **********************************************************************/

        public this ( size_t extent = 0 )
        in
        {
            assert (!this.outer.parking_stack_open);
            this.outer.parking_stack_open = true;
        }
        body
        {
            this.start = this.outer.n_free;
            this.end   = this.start;

            size_t extended = this.start + extent;

            if (this.outer.free_list.length < extended)
            {
                this.outer.free_list.length = extended;
            }
        }

        /**********************************************************************

            Destructor; clears the remaining stack elements.

         **********************************************************************/

        ~this ( )
        out
        {
            this.outer.parking_stack_open = false;
        }
        body
        {
            .clear(this[]);
        }

        /**********************************************************************

            Returns:
                the number of objects currently on the stack.

         **********************************************************************/

        size_t length ( )
        {
            return this.end - this.start;
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object to push

            Returns:
                object

         **********************************************************************/

        public void* push ( void* object )
        {
            return this.outer.recycle_(object, this.end++);
        }

        /**********************************************************************

            Pops an object from the stack.

            Returns:
                object popped from the stack or null if the stack is empty.

         **********************************************************************/

        public void* pop ( )
        {
            return (this.start < this.end)? this.outer.get_(--this.end) : null;
        }

        /**********************************************************************

            Returns:
                the current stack content.

         **********************************************************************/

        public void*[] opSlice ( )
        {
            return this.outer.free_list[this.start .. this.end];
        }

        /**********************************************************************

            'foreach' iteration, each cycle pops an element from the stack and
            iterates over it.

         **********************************************************************/

        public int opApply ( int delegate ( ref void* object ) dg )
        {
            int r = 0;

            for (void* object = this.pop(); object && !r; object = this.pop())
            {
                r = dg(object);
            }

            return r;
        }
    }
}
