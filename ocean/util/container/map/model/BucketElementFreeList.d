/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        06/07/2012: Initial release

    authors:        David Eckardt, Gavin Norman

    Free list of dynamically allocated objects.
    Implemented as a linked list; a subclass must get and set the next one of
    a given object.

*******************************************************************************/

module ocean.util.container.map.model.BucketElementFreeList;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.core.Array: clear;

/******************************************************************************/

abstract class FreeList
{
    /**************************************************************************

        First free element.

     **************************************************************************/

    private void* first = null;

    /**************************************************************************

        Free list length.

     **************************************************************************/

    private size_t n_free = 0;

    /**************************************************************************

        True while a ParkingStack instance for this instance exists.

     **************************************************************************/

    private bool parking_stack_open = false;

    /**************************************************************************

        Consistency check and assertion that at most one ParkingStack instance
        for this instance exists at a time.

     **************************************************************************/

    invariant ( )
    {
        if (this.first)
        {
            assert (this.n_free);
        }
        else
        {
            assert (!this.n_free);
        }

        assert (!this.parking_stack_open, "attempted to use the outer " ~
                typeof (this).stringof ~ " instance of an existing " ~
                ParkingStack.stringof ~ " instance");
    }

    /**************************************************************************

        Disposer.

     **************************************************************************/

    protected override void dispose ( )
    {
        this.first = null;
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
        if (this.first)
        {
            this.n_free--;

            return this.get_();
        }
        else
        {
            return new_object;
        }
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
        scope (success) this.n_free++;

        return this.recycle_(old_object);
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

        Obtains the next object of object. object is never null but the next
        object may be.

        Params:
            object = object of which to obtain the next object (is never null)

        Returns:
            the next object (which may be null).

     **************************************************************************/

    abstract protected void* getNext ( void* object );

    /**************************************************************************

        Sets the next object of object. object is never null but next may be.

        Params:
            object = object to which to set the next object (is never null)
            next   = next object for object (nay be null)

     **************************************************************************/

    abstract protected void setNext ( void* object, void* next );

    /**************************************************************************

        Obtains free_list[n] and sets free_list[n] to null.

        Params:
            n = free list index

        Returns:
            free_list[n]

     **************************************************************************/

    private void* get_ ( )
    in
    {
        assert (this.first);
    }
    body
    {
        void* element = this.first;

        this.first = this.getNext(element);

        this.setNext(element, null);

        return element;
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

    private void* recycle_ ( void* object )
    {
        this.setNext(object, this.first);

        return this.first = object;
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

        private size_t n = 0;

        /**********************************************************************

            Constructor.

            Params:
                extent = expected stack length for preallocation, if known.

         **********************************************************************/

        public this ( )
        in
        {
            assert (!this.outer.parking_stack_open);
            this.outer.parking_stack_open = true;
        }
        body { }

        /**********************************************************************

            Destructor; removes the remaining stack elements, if any.

         **********************************************************************/

        ~this ( )
        out
        {
            this.outer.parking_stack_open = false;
        }
        body
        {
            while (this.pop()) { }
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
            scope (success) this.n++;

            return this.outer.recycle_(object);
        }

        /**********************************************************************

            Pops an object from the stack.

            Returns:
                object popped from the stack or null if the stack is empty.

         **********************************************************************/

        public void* pop ( )
        {
            if (this.n)
            {
                scope (success) this.n--;

                return this.outer.get_();
            }
            else
            {
                return null;
            }
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
