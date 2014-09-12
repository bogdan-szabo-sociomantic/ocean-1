/*******************************************************************************

    Manages a pool of objects

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2010: Initial release

    authors:        David Eckardt

    The ObjectPool manages a pool of class instance objects.

    Usage:

    To manage instances of a class MyClass using ObjectPool, MyClass and its
    constructor argument types, if any, must be passed as ObjectPool class
    template instantiation parameters. Given that C is defined as

    ---

        class MyClass
        {
            this ( int ham, char[] eggs )
            { ... }

            void run ( float spam, bool sausage )
            { ... }
        }

    ---

    , the ObjectPool class template instantiation would be

    ---

        ObjectPool!(MyClass, int, char[])

    ---

    because the constructor of MyClass takes the int argument 'ham' and the
    char[] argument 'eggs'.

    The constructor of ObjectPool the arguments for the constructor of
    MyClass. Hence, an ObjectPool instance for MyClass as defined above is
    created by

    ---

        import $(TITLE)

        int    x = 42;
        char[] y = "Hello World!";

        ObjectPool!(MyClass, int, char[]) pool;

        pool = new ObjectPool!(MyClass, int, char[])(x, y);

    ---

    Since the "new ObjectPool ..." part is quite long, the ObjectPool class
    provides the newPool() factory method for convenience:

    ---

        import $(TITLE)

        int    x = 42;
        char[] y = "Hello World!";

        ObjectPool!(MyClass, int, char[]) pool;

        pool = pool.newPool(x, y);

    ---

*******************************************************************************/

module ocean.core.ObjectPool;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array: copy, copyExtend;


/*******************************************************************************

    Interface for pool items that offer a reset method. For each object stored
    in the object pool which implements this interface reset() is called when
    it is recycled or removed.

*******************************************************************************/

deprecated public interface Resettable
{
    void reset ( );
}

/*******************************************************************************

    Objects stored in an ObjectPoolImpl object pool must implement this
    interface. (The class passed to ObjectPool template parameter may or may not
    implement it.)

*******************************************************************************/

deprecated interface PoolItem
{
    /**************************************************************************

        Memorizes n.

        Params:
            n = value to memorize

    ***************************************************************************/

    void object_pool_index ( uint n );

    /**************************************************************************

        Returns the value that was previously passed as parameter to
        object_pool_index(uint). It is guaranteed that object_pool_index(uint)
        is called before this method.

         Returns:
             the value that was previously passed as parameter to
             object_pool_index(uint)

    ***************************************************************************/

    uint object_pool_index ( );
}

/*******************************************************************************

    Informational interface to an object pool, which only provides methods to
    get info about the state of the pool, no methods to modify anything.

*******************************************************************************/

deprecated public interface IObjectPoolInfo
{
    /**************************************************************************

        Returns the number of items in pool.

        Returns:
            the number of items in pool

     **************************************************************************/

    uint length ( );

    /**************************************************************************

        Returns the number of idle items in pool.

        Returns:
            the number of idle items in pool

     **************************************************************************/

    uint num_idle ( );

    /**************************************************************************

        Returns the number of busy items in pool.

        Returns:
            the number of busy items in pool

     **************************************************************************/

    uint num_busy ( );

    /**************************************************************************

        Returns the limit of items in pool

        Returns:
            limit of items in pool

     **************************************************************************/

    uint limit ( );

    /**************************************************************************

        Returns:
            true if the number of items in the pool is limited or fase otherwise

     **************************************************************************/

    bool is_limited ( );
}

/*******************************************************************************

    Extends Pool by creating items (instances of T) by "new T(args)".

    Template params:
        T    = class/struct type of objects to store, must have a dynamic
               "object_pool_index" member of type uint.
        Args = T constructor argument types, if T is a class.

*******************************************************************************/

deprecated class ObjectPool ( T, Args ... ) : Pool!(T)
{
    static if (Args.length)
    {
        private Args args;

        /******************************************************************

            Constructor

            Params:
                args = T constructor arguments to be used each time an
                       object is created

         ******************************************************************/

        this ( Args args )
        {
            static if (Args.length)
            {
                this.args = args;
            }
        }
    }

    /**************************************************************************

        Gets an object from the object pool.

        Returns:
            object from the object pool

     **************************************************************************/

    ItemType get ( )
    {
        return super.get(this.newItem());
    }

    /**************************************************************************

        Sets the limit of number of items in pool or disables limitation for
        limit = unlimited.

        Params:
            limit = new limit of number of items in pool; unlimited disables
                    limitation

        Returns:
            limit

        Throws:
            LimitExceededException if the number of busy pool items exceeds
            the desired limit

     **************************************************************************/

    uint limit ( uint limit )
    {
        return super.limit(limit, this.newItem());
    }

    /**************************************************************************

        (Workaround for compiler errors caused by failing method matching)

     **************************************************************************/

    override uint limit ( )
    {
        return super.limit();
    }

    /**************************************************************************

        Creates a new ObjectPool instance.

        Params:
            args = T constructor arguments to be used each time an object is
                   created

     **************************************************************************/

    static typeof (this) newPool ( Args args )
    {
        return new typeof (this)(args);
    }

    /**************************************************************************

        Creates a new pool item to be added to the pool.

        Returns:
            new pool item

    **************************************************************************/

    protected ItemType newItem ( )
    {
        static if (Args.length)
        {
            return new T(args);
        }
        else
        {
            return new T;
        }
    }
}

/*******************************************************************************

    Manages a pool of items of type T, if T is a class, or T* if T is a struct.
    Does not create the items ("new T") internally but receives them as lazy
    arguments in get() and limit().

*******************************************************************************/

deprecated class Pool ( T ) : PoolCore
{
    /***************************************************************************

        Asserts that T has dynamic "object_pool_index" member of type uint.

    ***************************************************************************/

    static if (is (typeof (T.object_pool_index) I))
    {
        static assert (!is (typeof (&(T.object_pool_index))), T.stringof ~ ".object_pool_index must not be a dynamic member");

        static assert (is (I == uint), T.stringof ~ ".object_pool_index must be uint, not " ~ I.stringof);

        static assert (is (typeof (T.init.object_pool_index = 4711)), T.stringof ~ ".object_pool_index must be assignable");
    }
    else static assert (false, "need dynamic \"uint " ~ T.stringof ~ ".object_pool_index\"");


    static if (is (T == class))
    {
        /***********************************************************************

            Pool item instance type alias.

        ***********************************************************************/

        alias T ItemType;

        /***********************************************************************

            Flag that indicates whether the item class is resettable.

        ***********************************************************************/

        const is_resettable = is (T : Resettable);
    }
    else
    {
        /***********************************************************************

            If not a class, the item type must be a struct.

        ***********************************************************************/

        static assert (is (T == struct), "Item type must be class or struct, not " ~ T.stringof ~ '.');

        /***********************************************************************

            Pool item instance type alias.

        ***********************************************************************/

        alias T* ItemType;

        /***********************************************************************

            Flag that indicates whether the item class is resettable.

        ***********************************************************************/

        static if (is (typeof (&S.reset) Reset))
        {
            const is_resettable = true;

            static assert (is (Reset == void function()), S.stringof ~ ".reset() must be 'void reset()'");
        }
        else
        {
            const is_resettable = false;
        }

    }

    /***************************************************************************

        get() and limit() may or may not accept or require an expression that
        returns "new T" depending on the following conditions:

        1. If T is a class that requires constructor arguments, get() and
           limit() require a "new T" expression.

        2. If T is a class with optional constructor arguments, get() and
           limit() accept a "new T" expression as an option. By default the T
           constructor is called without arguments.

        3. If T is a struct, get() and limit() do not accept a "new T"
           expression.

    ***************************************************************************/

    static if (is (T == class))
    {
        /***********************************************************************

            Takes an idle item from the pool or creates a new one if all item
            are busy or the pool is empty.

            Params:
                new_item = expression that creates a new Item instance

            Returns:
                pool item

            Throws:
                LimitExceededException if limitation is enabled and all pool
                items are busy.

        ***********************************************************************/

        deprecated public T get ( lazy T new_item )
        out (item)
        {
            assert (item.ptr !is null);
        }
        body
        {
            return this.fromItem(super.get_(Item.from(new_item)));
        }

        /***********************************************************************

            Sets the limit of number of items in pool or disables limitation for
            limit = unlimited.

            Params:
                limit    = new limit of number of items in pool; unlimited
                           disables limitation

                new_item = expression that creates a new Item instance

                Returns:
                    limit

            Throws:
                LimitExceededException if the number of busy pool items exceeds
                the desired limit.

         ***********************************************************************/

        deprecated public uint limit ( uint limit, lazy T new_item )
        {
            return super.limit_(limit, Item.from(new_item));
        }
    }

    static if (is (typeof (new T)))
    {
        /***********************************************************************

            Takes an idle item from the pool or creates a new one if all item
            are busy or the pool is empty.

            Returns:
                pool item

            Throws:
                LimitExceededException if limitation is enabled and all pool
                items are busy.

        ***********************************************************************/

        deprecated public ItemType get ( )
        out (item)
        {
            assert (item.ptr !is null);
        }
        body
        {
            return this.fromItem(super.get_(Item.from(new T)));
        }

        /***********************************************************************

            Sets the limit of number of items in pool or disables limitation for
            limit = unlimited.

            Params:
                limit = new limit of number of items in pool; unlimited disables
                        limitation

                Returns:
                    limit

            Throws:
                LimitExceededException if the number of busy pool items exceeds
                the desired limit.

         ***********************************************************************/

        deprecated public uint limit ( uint limit )
        {
            return super.limit_(limit, Item.from(new T));
        }
    }

    /**************************************************************************

        Obtains the n-th pool item. n must be less than the value returned by
        length().
        Caution: The item must not be recycled; while the item is in use, only
        opIndex(), opApply(), length() and limit() may be called.

        Params:
            n = item index

        Returns:
            n-th pool item

    **************************************************************************/

    deprecated public ItemType opIndex ( uint n )
    /+out (obj)
    {
        assert (obj !is null);
    }
    body+/
    {
        return this.fromItem(super.opIndex_(n));
    }

    /**************************************************************************

        Puts item back to the pool.

        Params:
            item = item to put back

        Returns:
            this instance

    **************************************************************************/

    deprecated public typeof (this) recycle ( ItemType item )
    {
        super.recycle_(Item.from(item));

        return this;
    }

    /**************************************************************************

        Returns the limit of number of items in pool or unlimited if currently
        unlimited.

        Returns:
            the limit of number of items in pool or 0 if currently unlimited

     **************************************************************************/

    override uint limit ( )
    {
        return super.limit();
    }

    /**************************************************************************

        Returns the member of the item union that is used by this instance.

        Params:
            item = item union instance

        Returns:
            the member of the item union that is used by this instance.

     **************************************************************************/

    static ItemType fromItem ( Item item )
    {
        static if (is (ItemType == class))
        {
            return cast (ItemType) item.obj;
        }
        else
        {
            return cast (ItemType) item.ptr;
        }
    }

    /**************************************************************************

        Sets the member of the item union that is used by this instance.

        Params:
            item = item to set to an item union instance

        Returns:
            item union instance with the member set that is used by this
            instance.

     **************************************************************************/

    static Item toItem ( ItemType item )
    {
        Item item_out;

        static if (is (ItemType == class))
        {
            item_out.obj = item;
        }
        else
        {
            item_out.ptr = item;
        }

        return item_out;
    }

    /**************************************************************************

        Sets the object pool index to item.

        Params:
            item = item to set index
            n    = index to set item to

     **************************************************************************/

    protected void setItemIndex ( Item item, uint n )
    {
        this.fromItem(item).object_pool_index = n;
    }

    /**************************************************************************

        Gets the object pool index of item.

        Params:
            item = item to get index from

        Returns:
            object pool index of item.

     **************************************************************************/

    protected uint getItemIndex ( Item item )
    {
        return this.fromItem(item).object_pool_index;
    }

    /**************************************************************************

        Resets item.

        Params:
            item = item to reset

     **************************************************************************/

    protected void resetItem ( Item item )
    {
        static if (this.is_resettable)
        {
            this.fromItem(item).reset();
        }
    }

    /**************************************************************************

        Deletes item and sets it to null.

        Params:
            item = item to delete

     **************************************************************************/

    protected void deleteItem ( ref Item item )
    out
    {
        assert (this.isNull(item));
    }
    body
    {
        static if (is (ItemType == class))
        {
            delete item.obj;
            item.obj = null;
        }
        else
        {
            delete item.ptr;
            item.ptr = null;
        }
    }

    /**************************************************************************

        Checks a and b for identity.

        Params:
            a = item to check for being indentical to b
            b = item to check for being indentical to a

        Returs:
            true if a and b are identical or false otherwise.

     **************************************************************************/

    protected bool isSame ( Item a, Item b )
    {
        return this.fromItem(a) is this.fromItem(b);
    }

    /**************************************************************************

        Checks if item is null.

        Params:
            item = item to check for being null

        Returs:
            true if item is null or false otherwise.

     **************************************************************************/

    protected bool isNull ( Item item )
    {
        return this.fromItem(item) is null;
    }

    /***************************************************************************

        Iterator classes, each one provides 'foreach' iteration over a subset
        if the items in the pool:

         - AllItemsIterator iterates over all items in the pool,
         - BusyItemsIterator iterates over the items that are busy on
           instantiation,
         - IdleItemsIteratoriterates over the items that are idle on
           instantiation.

        Usage Example:

        During iteration all Pool methods may be called except the limit setter.
        However, as indicated, the list of items iterated over is not updated to
        changes made by get(), recycle() and clear().

        ---
            import $(TITLE);

            void main ( )
            {
                class MyClass { uint object_pool_index; }

                auto pool = new Pool!(MyClass);

                // use pool

                scope busy_items = pool.new BusyItemsIterator;

                foreach (busy_item; busy_items)
                {
                    // busy_item now iterates over the items in the pool that
                    // were busy when busy_items was created.
                }
            }
        ---

        Note that, if the pool items are structs, 'ref' iteration is required to
        make the modification of the items iterated over permanent. For objects
        'ref' should not be used.

    ***************************************************************************/

    mixin ItemIterators!(T);

    /***************************************************************************

        'foreach' iteration method over the active items in the pool.

        During iteration all methods of ObjectPoolImpl may be called except
        limit(uint, PoolItem). However, the list of items iterated over is not
        updated to changes made by get(), recycle() and clear().

        TODO: This is superceded by the BusyItemsIterator.

    ***************************************************************************/

    deprecated public int opApply ( int delegate ( ref T item ) dg )
    {
        scope iterator = this.new BusyItemsIterator;

        return iterator.opApply(dg);
    }
}

/*******************************************************************************

    Actual pool implementation

*******************************************************************************/

abstract deprecated class PoolCore : IObjectPoolInfo
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

        static typeof (*this) from ( Object obj )
        {
            typeof (*this) item;

            item.obj = obj;

            return item;
        }

        static typeof (*this) from ( void* ptr )
        {
            typeof (*this) item;

            item.ptr = ptr;

            return item;
        }
    }

    /**************************************************************************

        Magic limit value indicating no limitation

     **************************************************************************/

    deprecated public const uint unlimited = uint.max;

    /**************************************************************************

        May be set to true at any time to limit the number of items in pool to
        the current number or to false to disable limitation.

     **************************************************************************/

    deprecated public bool limited = false;

    /**************************************************************************

        List of items (objects) in pool, busy items first

     **************************************************************************/

    private Item[] items;

    /**************************************************************************

        List of items (objects) in pool for safe iteration. items is copied into
        this array on safe iterator instantiation.

     **************************************************************************/

    private Item[] iteration_items;

    /**************************************************************************

        true if a safe iterator instance exists currently, used for assertions
        to ensure that only a single safe iterator can exist at a time (as it
        uses the single buffer, iteration_items, above).

     **************************************************************************/

    private bool safe_iterator_open = false;

    /**************************************************************************

        Count of unsafe iterator instances which exist currently, used for
        assertions to ensure that while an unsafe iterator exists the object
        pool may not be modified.

     **************************************************************************/

    private uint unsafe_iterators_open = 0;

    /**************************************************************************

        Number of busy items in pool

     **************************************************************************/

    private uint num_busy_ = 0;

    /**************************************************************************

        Reused exception instance

     **************************************************************************/

    private LimitExceededException limit_exception;

    /*************************************************************************/

    invariant ( )
    {
        assert (this.num_busy_ <= this.items.length);
    }

    /**************************************************************************

        Constructor

     **************************************************************************/

    deprecated public this ( )
    {
        this.limit_exception = this.new LimitExceededException;
    }

    /**************************************************************************

        Returns the number of items in pool.

        Returns:
            the number of items in pool

     **************************************************************************/

    deprecated public uint length ( )
    {
        return this.items.length;
    }

    /**************************************************************************

        Returns the number of busy items in pool.

        Returns:
            the number of busy items in pool

     **************************************************************************/

    deprecated public uint num_busy ( )
    {
        return this.num_busy_;
    }

    /**************************************************************************

        Returns the number of idle items in pool.

        Returns:
            the number of idle items in pool

     **************************************************************************/

    deprecated public uint num_idle ( )
    {
        return this.items.length - this.num_busy_;
    }

    /**************************************************************************

        Returns the limit of number of items in pool or unlimited if currently
        unlimited.

        Returns:
            the limit of number of items in pool or 0 if currently unlimited

     **************************************************************************/

    uint limit ( )
    {
        return this.limited? this.items.length : this.unlimited;
    }

    /**************************************************************************

        Returns:
            true if the number of items in the pool is limited or fase otherwise

     **************************************************************************/

    bool is_limited ( )
    {
        return this.limited;
    }

    /**************************************************************************

        Sets the limit of number of items in pool or disables limitation for
        limit = unlimited.

        Params:
            limit    = new limit of number of items in pool; unlimited disables
                       limitation

            new_item = expression that creates a new Item instance

        Returns:
            limit

        Throws:
            LimitExceededException if the number of busy pool items exceeds
            the desired limit.

     **************************************************************************/

    protected uint limit_ ( uint limit, lazy Item new_item )
    in
    {
        assert (!this.safe_iterator_open, "cannot set the limit while iterating over items");
        assert (!this.unsafe_iterators_open, "cannot set the limit while iterating over items");
    }
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

        if (this.limited && limit != this.items.length)
        {
            this.limit_exception.check(this.num_busy_ <= limit,
                                       "more items in pool busy than requested limit", __FILE__, __LINE__);

            uint n = this.items.length;

            if (limit < n) foreach (ref item; this.items[limit .. $])
            {
                this.resetItem(item);

                this.deleteItem(item);
            }

            this.items.length = limit;

            if (limit > n) foreach (ref item; this.items[n .. $])
            {
                item = new_item();
            }
        }

        return limit;
    }

    /**************************************************************************

        Takes an idle item from the pool or creates a new one if all item are
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
    in
    {
        assert (!this.unsafe_iterators_open, "cannot get from pool while iterating over items");
    }
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

            if (this.num_busy_ < this.items.length) foreach (item; this.items[this.num_busy_ + 1 .. $])
            {
                assert (!this.isSame(item, item_out));
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
            this.limit_exception.check(false, "all available items are busy", __FILE__, __LINE__);

            item = new_item();

            this.items ~= item;

            assert (!this.isNull(item));
        }

//        item.object_pool_index = this.num_busy_++;
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

        Note:
            Out contract is disabled because latsest DMD throws a compilation
            error.
            Bug is reported at http://d.puremagic.com/issues/show_bug.cgi?id=6058

    **************************************************************************/

    protected Item opIndex_ ( uint n )
    {
       return this.items[n];
    }

    /**************************************************************************

        Puts item back to the pool.

        Params:
            item = item to put back

    **************************************************************************/

    protected void recycle_ ( Item item_in )
    in
    {
        assert (this.num_busy_, "nothing is busy so there is nothing to recycle");

        uint index = this.getItemIndex(item_in);

        assert (index < this.items.length,
                "index of recycled item out of range");

        assert (this.isSame(item_in, this.items[index]), "wrong index in recycled item");

        assert (index < this.num_busy_, "recycled item is idle");

        assert (!this.unsafe_iterators_open, "cannot recycle while iterating over items");
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

        Recycles all items in the pool.

        Returns:
            this instance

    **************************************************************************/

    deprecated public PoolCore clear ( )
    in
    {
        assert (!this.unsafe_iterators_open, "cannot clear pool while iterating over items");
    }
    body
    {
        foreach (item; this.items[0..this.num_busy_])
        {
            this.resetItem(item);
        }

        this.num_busy_ = 0;

        return this;
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

    /***************************************************************************

        Iterator classes, each one provides 'foreach' iteration over a subset
        if the items in the pool.

        Note that, if the pool items are structs, 'ref' iteration is required to
        make the modification of the items iterated over permanent. For objects
        'ref' should not be used.

    ***************************************************************************/

    template ItemIterators ( T )
    {
        /***********************************************************************

            Base class for pool 'foreach' iterators. The constructor receives a
            slice of the items to be iterated over.

        ***********************************************************************/

        protected abstract scope class ItemsIterator
        {
            protected Item[] iteration_items;

            /*******************************************************************

                Constructor

                Params:
                    iteration_items = items to be iterated over (sliced)

            *******************************************************************/

            protected this ( Item[] iteration_items )
            {
                this.iteration_items = iteration_items;
            }

            /*******************************************************************

                'foreach' iteration over items[start .. end]

            *******************************************************************/

            deprecated public int opApply ( int delegate ( ref T item ) dg )
            {
                int ret = 0;

                foreach ( ref item; this.iteration_items )
                {
                    static if (is (T == class))
                    {
                        assert (item.obj !is null);

                        T item_out = cast (T) item.obj;

                        ret = dg(item_out);
                    }
                    else
                    {
                        assert (item.ptr !is null);

                        ret = dg(*cast (T*) item.ptr);
                    }

                    if ( ret )
                    {
                        break;
                    }
                }

                return ret;
            }
        }

        /***********************************************************************

            Provides 'foreach' iteration over items[start .. end]. During
            iteration all methods of PoolCore may be called except limit_().

            The iteration is actually over a copy of the items in the pool which
            are specified in the constructor. Thus the pool may be modified
            while iterating. However, the list of items iterated over is not
            updated to changes made by get(), clear() and recycle().

        ***********************************************************************/

        protected abstract scope class SafeItemsIterator : ItemsIterator
        {
            /*******************************************************************

                Constructor

                Params:
                    start = start item index
                    end   = end item index (excluded like array slice end index)

                In:
                    No instance of this class may exist.

            *******************************************************************/

            protected this ( uint start, uint end )
            in
            {
                assert (!this.outer.safe_iterator_open);
            }
            body
            {
                this.outer.safe_iterator_open = true;
                auto slice = this.outer.iteration_items.copyExtend(
                    this.outer.items[start .. end]);
                super(slice);
            }

            /*******************************************************************

                Destructor

            *******************************************************************/

            ~this ( )
            {
                this.outer.safe_iterator_open = false;
            }
        }

        /***********************************************************************

            Provides 'foreach' iteration over items[start .. end]. During
            iteration only read-only methods of PoolCore may be called.

            The unsafe iterator is more efficient as it does not require the
            copy of the items being iterated, which the safe iterator performs.

        ***********************************************************************/

        protected abstract scope class UnsafeItemsIterator : ItemsIterator
        {
            /*******************************************************************

                Constructor

                Params:
                    start = start item index
                    end   = end item index (excluded like array slice end index)

            *******************************************************************/

            protected this ( uint start, uint end )
            {
                this.outer.unsafe_iterators_open++;
                super(this.outer.items[start .. end]);
            }

            /*******************************************************************

                Destructor

            *******************************************************************/

            ~this ( )
            {
                this.outer.unsafe_iterators_open--;
            }
        }

        /***********************************************************************

            Provides safe 'foreach' iteration over all items in the pool.

        ***********************************************************************/

        scope class AllItemsIterator : SafeItemsIterator
        {
            this ( )
            {
                super(0, this.outer.items.length);
            }
        }

        /***********************************************************************

            Provides unsafe 'foreach' iteration over all items in the pool.

        ***********************************************************************/

        scope class ReadOnlyAllItemsIterator : UnsafeItemsIterator
        {
            this ( )
            {
                super(0, this.outer.items.length);
            }
        }

        /***********************************************************************

            Provides safe 'foreach' iteration over the busy items in the pool.

        ***********************************************************************/

        scope class BusyItemsIterator : SafeItemsIterator
        {
            this ( )
            {
                super(0, this.outer.num_busy_);
            }
        }

        /***********************************************************************

            Provides unsafe 'foreach' iteration over the busy items in the pool.

        ***********************************************************************/

        scope class ReadOnlyBusyItemsIterator : UnsafeItemsIterator
        {
            this ( )
            {
                super(0, this.outer.num_busy_);
            }
        }

        /***********************************************************************

            Provides safe 'foreach' iteration over the idle items in the pool.

        ***********************************************************************/

        scope class IdleItemsIterator : SafeItemsIterator
        {
            this ( )
            {
                super(this.outer.num_busy_, this.outer.items.length);
            }
        }

        /***********************************************************************

            Provides unsafe 'foreach' iteration over the idle items in the pool.

        ***********************************************************************/

        scope class ReadOnlyIdleItemsIterator : UnsafeItemsIterator
        {
            this ( )
            {
                super(this.outer.num_busy_, this.outer.items.length);
            }
        }
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


/*******************************************************************************

    UnitTest

    TODO: adapt to changes in ObjectPool/ObjectPoolImpl

    The whole unittest is disabled because it corrupts memory as it is.

*******************************************************************************/

version (none) // ( UnitTest )
{
    // Uncomment the next line to see UnitTest output
    // version = UnitTestVerbose;

    deprecated class MyClass : Resettable
    {
        uint object_pool_index;
        private char[] name;
        private void delegate() callOnDeath, callOnReset;


        public this ( char[] name, void delegate() death, void delegate() reset )
        {
            this.name = name;
            this.callOnDeath = death;
            this.callOnReset = reset;

        }

        public this()
        {
            this.name = "default";
            this.callOnDeath = null;

        }

        protected void reset()
        {

            if(callOnReset)
                callOnReset();
        }

        public ~this ( )
        {
            if(callOnDeath)
                callOnDeath();
        }
    }

    import tango.math.random.Random;
    import tango.time.StopWatch;
    import tango.core.Memory;
    import tango.io.FilePath;

    deprecated unittest
    {
        /***********************************************************************

            General testing of most functions and behavior

        ***********************************************************************/

        {
            bool reset=false, death = false;

            void resetFunc()
            {
                reset = true;
            }
            void deathFunc()
            {
                death = true;
            }


            {
                scope tmp = ObjectPool!(MyClass).newPool();
                auto a = tmp.get();
                assert(tmp.length == 1);
            }

            scope pool1 = new ObjectPool!(MyClass, char[],
                                          void delegate(),void delegate())
                                          ("one" , &deathFunc,&resetFunc);


            // Test limit related query/set functions

            pool1.limit(5);
            assert(pool1.limited);
            assert(pool1.limit == 5);

            auto a = pool1.get();

            auto b = pool1.get();
            pool1.recycle(b);

            assert(pool1.num_idle == 4);
            assert(pool1.num_busy == 1);
            assert(pool1.length == 5);

            auto c = pool1.get();
            pool1.recycle(cast(MyClass)c);
            assert(pool1.length == 5);

            auto d = pool1.get();
            {
                reset = death = false;

                pool1.recycle(d);

                assert(reset,"Reset should be set");


                assert(pool1.length == 5);

                death = reset = false;
            }

            assert(pool1.limit == 5);

            d = pool1.get();
            auto e = pool1.get();

            // Test setting a to small limit
            {
                auto caught = false;

                try pool1.limit(1);
                catch (Exception e) caught = true;

                assert(caught);
            }

            assert(pool1.limit == 5);

            c = pool1.get();
            d = pool1.get();

            assert (pool1.length == 5);


            // Test limit
            {
                auto caught = false;

                try
                {
                    auto fail = pool1.get();
                }
                catch (Exception e)
                {
                    caught = true;
                }

                assert (caught);

            }

            pool1.limit(6);
            assert(pool1.limit == 6);
            auto f = pool1.get();

            assert (pool1.length == 6);
            assert (pool1.num_idle == 0);
            assert (pool1.num_busy == 6);

            pool1.recycle(a);

            assert (pool1.length == 6);
            assert (pool1.num_idle == 1);
            assert (pool1.num_busy == 5);

            pool1.limit(5);

            assert (pool1.length == 5);
            assert (pool1.num_idle == 0);
            assert (pool1.num_busy == 5);
        }
    }
}

