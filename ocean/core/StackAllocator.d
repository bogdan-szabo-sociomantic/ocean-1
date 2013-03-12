/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-02-22: Initial release

    Authors:        Gavin Norman

    Helper class to allow the separation of the allocation of space on the stack
    from the instatiation of an object in that space.

    This is useful in the situation where, for example, you wish to allocate a
    class instance on the stack (with the scope attribute), but the exact type
    of the class to be allocated is not known at the point where the stack space
    needs to be allocated. The usage example below demonstrates this usage
    pattern.

    This module is based on the example here from Walter:
        http://www.digitalmars.com/techtips/class_objects.html

    Note (from the above url):
        This technique goes "under the hood" of how D works, and as such it is
        not guaranteed to work with every D compiler. In particular, how the
        constructors and destructors are called is not necessarilly portable.

    Usage example:

    ---

        import ocean.core.StackAllocator;
        import ocean.io.Stdout;

        abstract class IClass
        {
            private int x;

            public this ( int x )
            {
                this.x = x;
            }

            public void print ( )
            {
                Stdout.formatln("{}: {}", this.id, this.x);
            }

            protected char[] id ( );
        }

        class ClassA : IClass
        {
            public this ( int x )
            {
                super(x);
            }

            protected char[] id ( )
            {
                return "ClassA";
            }
        }

        class ClassB : IClass
        {
            public this ( int x )
            {
                super(x);
            }

            protected char[] id ( )
            {
                return "ClassB";
            }
        }

        IClass allocate ( StackAllocator!() stack_alloc, bool a )
        {
            if ( a )
            {
                return stack_alloc.allocate!(ClassA)(23);
            }
            else
            {
                return stack_alloc.allocate!(ClassB)(23);
            }
        }

        void main ( )
        {
            bool a;
            while ( true )
            {
                scope stack_alloc = new StackAllocator!();
                auto obj = allocate(stack_alloc, a);
                obj.print();

                a = !a;
            }
        }

    ---

*******************************************************************************/

module ocean.core.StackAllocator;

version ( DigitalMars )
{
    /***************************************************************************

        This is part of the D internal runtime library support

    ***************************************************************************/

    extern ( C ) void _d_callfinalizer( void* p );


    /***************************************************************************

        Class template to reserve a certain number of bytes on the stack, and
        allow an object to later be allocated into that space.

        The class can be safely newed on the stack (as scope), as it performs no
        heap allocations internally.

        Template params:
            BufferSize = number of bytes to reserve on the stack

    ***************************************************************************/

    public class StackAllocator ( size_t BufferSize = 4096 )
    {
        /***********************************************************************

            Static array of bytes into which a class instance can be allocated.
            According to Luca, static arrays are always GC-scanned, so it's safe
            to declare this as ubyte (rather than the more usual void[] buffer
            for GC-scanning).

        ***********************************************************************/

        private ubyte[BufferSize] buf;


        /***********************************************************************

            Pointer to allocated class instance.

        ***********************************************************************/

        private void* p;


        /***********************************************************************

            Destructor. Calls the destructor of an object which has been
            allocated in this.buf.

        ***********************************************************************/

        ~this ( )
        {
            if ( p )
            {
                _d_callfinalizer(p);
            }
        }


        /***********************************************************************

            Allocates an instance of the specified type into the stack buffer
            this.buf.

            The class T must have a constructor which accepts the tuple of
            arguments specified by Args. Note that in the case where Args is of
            length 0, T *must* have an explicitly declared ctor accepting no
            arguments.

            Template params:
                T = type of class to allocate
                Args = tuple of arguments to pass to T's constructor

            Params:
                c_args = arguments to pass to T's constructor

            In:
                Asserts that p is null (i.e. that an object has not already been
                allocated into this.buf). Theoretically we could deallocate an
                existing object (as per the destructuor, above), but this would
                invalidate any existing references to that object.

            FIXME: this method causes a segfault if T is an abstract class. Is
            there a way to detect this at compile time?

        ***********************************************************************/

        public T allocate ( T : Object, Args ... ) ( Args c_args )
        in
        {
            assert(this.p is null, "Already allocated an object");
        }
        body
        {
            ClassInfo ci = T.classinfo;
            T t;

            // Allocate space
            assert(ci.init.length <= this.buf.length);
            this.p = buf.ptr;

            // Initialize it
            (cast(byte*)this.p)[0 .. ci.init.length] = ci.init[];

            t = cast(T)this.p;

            // Run constructor on it
            t._ctor(c_args);

            return t;
        }
    }


    /***************************************************************************

        Class template wrapping a stack allocator and an allocated instance of
        the specified class.

        The class can be safely newed on the stack (as scope), as it performs no
        heap allocations internally.

        Template params:
            T = type of object to allocate using the stack allocator
            BufferSize = number of bytes to reserve on the stack

    ***************************************************************************/

    public class StackAllocated ( T : Object, size_t BufferSize = 4096 )
        : StackAllocator!(BufferSize)
    {
        /***********************************************************************

            Instance of T.

        ***********************************************************************/

        private T instance;


        /***********************************************************************

            Gets the stack allocated instance of T. If the instance has not yet
            been allocated, it is allocated at this point.

            Template params:
                T = type of class to allocate
                Args = tuple of arguments to pass to T's constructor

            Params:
                c_args = arguments to pass to T's constructor

            Returns:
                reference to stack allocated T instance

        ***********************************************************************/

        public T opCall ( C : T = T, Args ... ) ( Args c_args )
        out ( t )
        {
            assert(t !is null, "stack allocated instance is null");
        }
        body
        {
            if ( this.instance is null )
            {
                this.instance = super.allocate!(C)(c_args);
            }

            return this.instance;
        }
    }
}
else
{
    static assert(false, "module ocean.core.StackAllocator only supported with dmd compilers");
}

