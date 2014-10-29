/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        15/08/2012: Initial release

    authors:        Gavin Norman

    Base class for all types of pool. Provides the following features:
        * A set of items, each either busy or idle.
        * Idle items can be got from the pool, thus becoming busy, using get().
        * Busy items can be returned to the pool, thus becoming idle, with
          recycle().
        * The total number of items in the pool, as well as the number of busy
          or idle items can be queried.
        * The entire pool can be emptied, returning all items to the idle state,
          with clear().
        * A limit can be applied to the pool, which prevents more than the
          specified number of items from being created.
        * A specified number of items can be pre-allocated in the pool using the
          fill() method.

    Each item in the pool has an index, which allows a simple lookup of an item
    to its position in the internal array of items. The item index is defined by
    the abstract methods setItemIndex() and getItemIndex() (i.e. in the base
    class there is no definition of how this item index is implemented).

    Note that the IPool class is abstract, and provides only the internal
    framework required for getting and recycling pool items (see get_() and
    recycle_()).

*******************************************************************************/

module ocean.util.container.pool.model.IPool;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.pool.model.IPoolInfo;
import ocean.util.container.pool.model.ILimitable;

import ocean.core.Array: copy;



/*******************************************************************************

    Core pool implementation.

*******************************************************************************/

public abstract class IPool : IPoolInfo, ILimitable
{
    /***************************************************************************

        Pool item union. The list of pool items is an array of Item; the
        subclass specifies which member is actually used.

    ***************************************************************************/

    protected union Item
    {
        /***********************************************************************

            Object to store class instances in the pool

        ***********************************************************************/

        Object obj;

        /***********************************************************************

            Pointer to store struct instances in the pool

        ***********************************************************************/

        void* ptr;

        /***********************************************************************

            Creates an instance of this type from an object.

            Params:
                obj = object to store in union

        ***********************************************************************/

        static typeof (*this) from ( Object obj )
        {
            typeof (*this) item;

            item.obj = obj;

            return item;
        }

        /***********************************************************************

            Creates an instance of this type from a pointer.

            Params:
                ptr = pointer to store in union

        ***********************************************************************/

        static typeof (*this) from ( void* ptr )
        {
            typeof (*this) item;

            item.ptr = ptr;

            return item;
        }
    }

    /**************************************************************************

        Maximum number of items allowed when the pool is limited. This value has
        no meaning if this.limited is false.

     **************************************************************************/

    private uint limit_max;

    /**************************************************************************

        May be set to true at any time to limit the number of items in pool to
        the current number or to false to disable limitation.

     **************************************************************************/

    public bool limited = false;

    /**************************************************************************

        List of items (objects) in pool, busy items first

     **************************************************************************/

    protected Item[] items;

    /**************************************************************************

        Number of busy items in pool

     **************************************************************************/

    protected uint num_busy_ = 0;

    /**************************************************************************

        Reused exception instance

     **************************************************************************/

    private LimitExceededException limit_exception;

    /*************************************************************************/

    invariant ()
    {
        assert (this.num_busy_ <= this.items.length);
    }

    /**************************************************************************

        Constructor

     **************************************************************************/

    public this ( )
    {
        this.limit_exception = this.new LimitExceededException;
    }

    /**************************************************************************

        Returns the number of items in pool.

        Returns:
            the number of items in pool

     **************************************************************************/

    public uint length ( )
    {
        return this.items.length;
    }

    /**************************************************************************

        Returns the number of busy items in pool.

        Returns:
            the number of busy items in pool

     **************************************************************************/

    public uint num_busy ( )
    {
        return this.num_busy_;
    }

    /**************************************************************************

        Returns the number of idle items in pool.

        Returns:
            the number of idle items in pool

     **************************************************************************/

    public uint num_idle ( )
    {
        return this.items.length - this.num_busy_;
    }

    /**************************************************************************

        Returns the limit of number of items in pool or unlimited if currently
        unlimited.

        Returns:
            the limit of number of items in pool or 0 if currently unlimited

     **************************************************************************/

    public uint limit ( )
    {
        return this.limited? this.limit_max : this.unlimited;
    }

    /**************************************************************************

        Returns:
            true if the number of items in the pool is limited or fase otherwise

     **************************************************************************/

    public bool is_limited ( )
    {
        return this.limited;
    }

    /**************************************************************************

        Recycles all items in the pool.

        Returns:
            this instance

    **************************************************************************/

    public typeof(this) clear ( )
    {
        foreach (item; this.items[0..this.num_busy_])
        {
            this.resetItem(item);
        }

        this.num_busy_ = 0;

        return this;
    }

    /**************************************************************************

        Sets the limit of number of items in pool or disables limitation for
        limit = unlimited. When limiting the pool, any excess idle items are
        reset and deleted.

        Params:
            limit = new limit of number of items in pool; unlimited disables
               limitation

        Returns:
            new limit

        Throws:
            LimitExceededException if the number of busy pool items exceeds
            the desired limit.

     **************************************************************************/

    public uint setLimit ( uint limit )
    out
    {
        debug (ObjectPoolConsistencyCheck) foreach (item; this.items)
        {
            assert (item.ptr !is null);
        }
    }
    body
    {
        this.limited = limit != this.unlimited;

        if ( this.limited )
        {
            this.limit_exception.check(this.num_busy_ <= limit,
                "pool already contains more busy items than requested limit",
                __FILE__, __LINE__);

            this.limit_max = limit;

            if ( limit < this.items.length )
            {
                this.truncate(this.items.length - limit);
            }
        }

        return limit;
    }

    /**************************************************************************

        Ensures that the pool contains at least the specified number of items.
        Useful to pre-allocate a pool of a certain size.

        Params:
            num = minimum number of items desired in pool
            new_item = expression that creates a new Item instance

        Returns:
            this

        Throws:
            LimitExceededException if the requested number of items exceeds
            the previously specified limit.

     **************************************************************************/

    protected typeof(this) fill_ ( size_t num, lazy Item new_item )
    {
        if ( this.items.length < num )
        {
            this.limit_exception.check(num <= limit,
                "cannot fill pool to larger than specified limit", __FILE__,
                __LINE__);

            auto old_len = this.items.length;
            this.items.length = num;

            foreach ( ref item; this.items[old_len .. $] )
            {
                item = new_item();
                assert (!this.isNull(item));
            }
        }

        return this;
    }

    /**************************************************************************

        Takes an idle item from the pool or creates a new one if all items are
        busy or the pool is empty.

        Params:
            new_item = expression that creates a new Item instance

        Returns:
            pool item

        Throws:
            LimitExceededException if limitation is enabled and all pool items
            are busy

    **************************************************************************/

    protected Item get_ ( lazy Item new_item )
    out (item_out)
    {
        assert (!this.isNull(item_out));

        assert (this.isSame(item_out, this.items[this.num_busy_ - 1]));

        debug (ObjectPoolConsistencyCheck)
        {
            foreach (item; this.items[0 .. this.num_busy_ - 1])
            {
                assert (!this.isSame(item, item_out));
            }

            if (this.num_busy_ < this.items.length)
            {
                foreach (item; this.items[this.num_busy_ + 1 .. $])
                {
                    assert (!this.isSame(item, item_out));
                }
            }
        }
    }
    body
    {
        Item item;

        if (this.num_busy_ < this.items.length)
        {
            item = this.items[this.num_busy_];

            assert (!this.isNull(item));
        }
        else
        {
            this.limit_exception.check(this.num_busy_ < this.limit,
                "limit reached: no free items", __FILE__, __LINE__);

            item = new_item();

            this.items ~= item;

            assert (!this.isNull(item));
        }

        this.setItemIndex(item, this.num_busy_++);

        return item;
    }

    /**************************************************************************

        Obtains the n-th pool item. n must be less than the value returned by
        length().

        Caution: The item must not be recycled; while the item is in use, only
        opIndex(), opApply() and length() may be called.

        Params:
            n = item index

        Returns:
            n-th pool item

    **************************************************************************/

    protected Item opIndex_ ( uint n )
    {
       return this.items[n];
    }

    /***************************************************************************

        Puts item back to the pool.

        Params:
            item = item to put back

    ***************************************************************************/

    protected void recycle_ ( Item item_in )
    in
    {
        assert (this.num_busy_, "nothing is busy so there is nothing to recycle");

        uint index = this.getItemIndex(item_in);

        assert (index < this.items.length,
                "index of recycled item out of range");

        assert (this.isSame(item_in, this.items[index]), "wrong index in recycled item");

        assert (index < this.num_busy_, "recycled item is idle");
    }
    body
    {
        uint index = this.getItemIndex(item_in);

        Item* item            = this.items.ptr + index,
              first_idle_item = this.items.ptr + --this.num_busy_;

        this.resetItem(item_in);

        *item = *first_idle_item;

        *first_idle_item = item_in;

        this.setItemIndex(*item, index);

        this.setItemIndex(*first_idle_item, this.num_busy_);
    }

    /**************************************************************************

        Sets the object pool index to item.

        Params:
            item = item to set index
            n    = index to set item to

     **************************************************************************/

    abstract protected void setItemIndex ( Item item, uint n );

    /**************************************************************************

        Gets the object pool index of item.

        Params:
            item = item to get index from

        Returns:
            object pool index of item.

     **************************************************************************/

    abstract protected uint getItemIndex ( Item item );

    /**************************************************************************

        Resets item.

        Params:
            item = item to reset

     **************************************************************************/

    abstract protected void resetItem ( Item item );

    /**************************************************************************

        Deletes item and sets it to null.

        Params:
            item = item to delete

     **************************************************************************/

    abstract protected void deleteItem ( ref Item item );

    /**************************************************************************

        Checks a and b for identity.

        Params:
            a = item to check for being indentical to b
            b = item to check for being indentical to a

        Returs:
            true if a and b are identical or false otherwise.

     **************************************************************************/

    abstract protected bool isSame ( Item a, Item b );

    /**************************************************************************

        Checks if item is null.

        Params:
            item = item to check for being null

        Returs:
            true if item is null or false otherwise.

     **************************************************************************/

    abstract protected bool isNull ( Item item );

    /**************************************************************************

        Removes idle items from the pool. Excess idle items are reset and
        deleted.

        Params:
            remove = number of idle items to remove from pool

     **************************************************************************/

    protected void truncate ( size_t remove )
    {
        assert(remove <= this.num_idle);

        foreach ( ref item; this.items[this.items.length - remove .. $] )
        {
            this.resetItem(item);
            this.deleteItem(item);
        }

        this.items.length = this.items.length - remove;
    }

    /***************************************************************************

        LimitExceededException class

    ***************************************************************************/

    class LimitExceededException : Exception
    {
        /***********************************************************************

            Limit which was exceeded when this instance has been thrown

        ***********************************************************************/

        uint limit;

        /***********************************************************************

            Constructor

        ***********************************************************************/

        this ( ) {super("");}

        /***********************************************************************

            Throws this instance if ok is false and limitation is enabled.

            Params:
                ok   = condition to check if limitation is enabled
                msg  = message
                file = source code file
                line = source code line

            Throws:
                this instance if ok is false and limitation is enabled

        ***********************************************************************/

        void check ( bool ok, lazy char[] msg, char[] file, long line )
        {
            if (this.outer.limited && !ok)
            {
                this.limit = this.outer.items.length;

                super.msg.copy(msg);
                super.file.copy(file);
                super.line = line;

                throw this;
            }
        }
    }
}

