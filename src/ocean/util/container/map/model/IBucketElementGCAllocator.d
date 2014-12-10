/*******************************************************************************

    Copyright:      Copyright (C) 2013 sociomantic labs. All rights reserved

    Version:        2013-08-06: Initial release

    Author:        David Eckardt

    Base class for a bucket element allocator using the D runtime memory
    manager. Even though this memory manager is called "GC-managed" this class
    in fact doesn't rely on garbage collection but explicitly deletes unused
    bucket elements.

*******************************************************************************/

module ocean.util.container.map.model.IBucketElementGCAllocator;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.map.model.IAllocator;

/******************************************************************************/

class IBucketElementGCAllocator: IAllocator
{
    /***************************************************************************

        Allocates a bucket element.

        Returns:
            a bucket element that is ready to use.

    ***************************************************************************/

    abstract public void* get ( );

    /***************************************************************************

        Deletes a bucket element that is no longer used.

        Params:
            element = old bucket element

    ***************************************************************************/

    public void  recycle ( void* element )
    {
        delete element;
    }

    /***************************************************************************

        Helper class to temprarily park a certain number of bucket elements.

    ***************************************************************************/

    static scope class ParkingStack: IParkingStack
    {
        /***********************************************************************

            List of parked object.

        ***********************************************************************/

        private void*[] elements;

        /***********************************************************************

            Constructor.

            Params:
                n = number of objects that will be parked

        ***********************************************************************/

        public this ( size_t n )
        {
            super(n);
            this.elements = new void*[n];
        }

        /***********************************************************************

            Disposer.

        ***********************************************************************/

        protected override void dispose ( )
        {
            delete this.elements;
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object = object to push
                n      = number of parked objects before object is pushed
                         (guaranteed to be less than max_length)

         **********************************************************************/

        protected void push_ ( void* element, size_t n )
        {
            this.elements[n] = element;
        }

        /**********************************************************************

            Pops an object from the stack. This method is never called if the
            stack is empty.

            Params:
                n = number of parked objects after object is popped (guaranteed
                    to be less than max_length)

            Returns:
                object popped from the stack or null if the stack is empty.

         **********************************************************************/

        protected void* pop_ ( size_t n )
        {
            return this.elements[n];
        }
    }

    /***************************************************************************

        Calls dg with an IParkingStack instance that is set up to keep n
        elements.

        Params:
            n  = number of elements to park
            dg = delegate to call with the IParkingStack instance

    ***************************************************************************/

    public void parkElements ( size_t n, void delegate ( IParkingStack park ) dg )
    {
        scope park = new ParkingStack(n);
        dg(park);
    }
}
