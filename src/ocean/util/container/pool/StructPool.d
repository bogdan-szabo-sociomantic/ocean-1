/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        15/08/2012: Initial release

    authors:        Gavin Norman

    Pool class template which stores struct instances, has the following
    features:
        * Get and recycle items. Recycled items will be re-used before creating
          new items.
        * The total number of items, as well as the number of idle or busy items
          in the pool can be queried.
        * A limit can be applied to the pool, which prevents more than the
          specified number of items from being created.
        * A specified number of items can be pre-allocated in the pool using the
          fill() method.
        * The entire pool can be emptied, returning all items to the idle state,
          with clear().
        * Iteration over all items in the pool, or all busy or idle items. (See
          further notes in the super class.)
        * get() and fill() methods exist which automatically create new pool
          items, without requiring them to be passed via a lazy argument.

    Also see: ocean.util.container.pool.model.IAggregatePool, for more detailed
    documentation and usage examples.

*******************************************************************************/

module ocean.util.container.pool.StructPool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.container.pool.model.IAggregatePool;

private import ocean.core.Traits : hasMethod;



/*******************************************************************************

    Manages a pool of struct instances of type T.

    Template params:
        T = type stored in pool

*******************************************************************************/

public class StructPool ( T ) : IAggregatePool!(T)
{
    /***************************************************************************

        Asserts that T is a struct.

    ***************************************************************************/

    static assert(is(T == struct));

    /**************************************************************************

        Resets item.

        If T has a method of type:

            void reset ( )

        then this method will be called for the given item.

        Params:
            item = item to reset

     **************************************************************************/

    protected void resetItem ( Item item )
    {
        static if (is (typeof (T.reset) Reset))
        {
            static assert(hasMethod!(T, "reset", void delegate()),
                T.stringof ~ ".reset() must be 'void reset()'");

            this.fromItem(item).reset();
        }
    }
}



debug ( UnitTest )
{
    struct Struct
    {
        uint object_pool_index;

        int i;
        char[] s;

        void reset ( )
        {

        }
    }

    alias StructPool!(Struct) MyPool;
    class StructPoolTester : IAggregatePoolTester!(Struct)
    {
        public this ( )
        {
            super(new MyPool);
        }

        protected Item newItem ( )
        {
            return new Struct;
        }

        protected void setItem ( ref Item item, int i )
        {
            item.i = i;
            item.s.length = 1;
            item.s[0] = cast(char)(i + 32);
        }

        protected void checkItem ( ref Item item, int i )
        {
            assert(item.i == i, "item integer wrong");
            assert(item.s.length == 1, "item string length wrong");
            assert(item.s[0] == cast(char)(i + 32), "item string content wrong");
        }
    }

    unittest
    {
        scope sp = new StructPoolTester;
        sp.test();
    }
}

