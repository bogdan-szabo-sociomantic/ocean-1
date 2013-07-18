/*******************************************************************************

    Copyright:      Copyright (C) 2013 sociomantic labs. All rights reserved

    Version:        2013-07-10: Initial release

    Author:        David Eckardt

    Interface for an object allocator.

*******************************************************************************/

module ocean.util.container.map.model.IAllocator;

/******************************************************************************/

interface IAllocator
{
    /***************************************************************************

        Gets or allocates an object

        Returns:
            an object that is ready to use.

    ***************************************************************************/

    void* get ( );

    /***************************************************************************

        Recycles or deletes an object that is no longer used.

        Note: Strictly specking old should be a ref to satisfy D's delete
        expression which wants the pointer as an lvalue in order to set it to
        null after deletion. However, would make code more complex and isn't
        actually necessary in the particular use case of this interface (see
        BucketSet.remove()/clear()).

        Params:
            old = old object

    ***************************************************************************/

    void recycle ( void* old );

    /***************************************************************************

        Helper class to temprarily park a certain number of objects.

    ***************************************************************************/

    static abstract scope class IParkingStack
    {
        /**********************************************************************

            Maximum number of objects as passed to the constructor.

         **********************************************************************/

        public const size_t max_length;

        /**********************************************************************

            Number of elements currently on the stack. This value is always
            at most max_length.

         **********************************************************************/

        private size_t n = 0;

        /**********************************************************************

            Constructor.

            Params:
                max_length = maximum number of objects that will be stored

         **********************************************************************/

        protected this ( size_t max_length )
        {
            this.max_length = max_length;
        }

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object = object to push

            Returns:
                object

            In:
                Less than max_length objects may be parked.

         **********************************************************************/

        public void* push ( void* object )
        in
        {
            assert(this.n < this.max_length);
        }
        out
        {
            assert(this.n <= this.max_length);
        }
        body
        {
            this.push_(object, this.n++);

            return object;
        }

        /**********************************************************************

            Pops an object from the stack.

            Returns:
                object popped from the stack or null if the stack is empty.

            Out:
                At most max_length objects are parked.

         **********************************************************************/

        public void* pop ( )
        out (element)
        {
            assert(this.n <= this.max_length);
        }
        body
        {
            if (this.n)
            {
                return this.pop_(--this.n);
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

        /**********************************************************************

            Pushes an object on the stack.

            Params:
                object = object to push
                n      = number of parked objects before object is pushed
                         (guaranteed to be less than max_length)

         **********************************************************************/

        abstract protected void push_ ( void* object, size_t n );

        /**********************************************************************

            Pops an object from the stack. This method is never called if the
            stack is empty.

            Params:
                n = number of parked objects after object is popped (guaranteed
                    to be less than max_length)

            Returns:
                object popped from the stack or null if the stack is empty.

         **********************************************************************/

        abstract protected void* pop_ ( size_t n );
    }

    /***************************************************************************

        Calls dg with an IParkingStack instance that is set up to keep n
        elements.

        Params:
            n  = number of elements to park
            dg = delegate to call with the IParkingStack instance

    ***************************************************************************/

    void parkElements ( size_t n, void delegate ( IParkingStack park ) dg );
}
