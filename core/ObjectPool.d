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

private import ocean.core.Array: copy;

debug private import tango.util.log.Trace;

/*******************************************************************************

    Interface for pool items that offer a reset method. For each object stored
    in the object pool which implements this interface reset() is called when
    it is recycled or removed.

*******************************************************************************/

public interface Resettable
{
    void reset ( );
}

/*******************************************************************************

    Objects stored in an ObjectPoolImpl object pool must implement this
    interface. (The class passed to ObjectPool template parameter may or may not
    implement it.)

*******************************************************************************/

interface PoolItem
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

interface IObjectPoolInfo
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

    ObjectPool class template. Extends ObjectPoolImpl by creating instances of
    a subclass of C, CustomRecyclable. CustomRecyclable extends C by a recycle()
    method so that each CustomRecyclable object can return itself back to the
    pool.
    
    Template params:
        C    = class of objects to store, may or may not implement PoolItem
        Args = C constructor argument types

*******************************************************************************/

class ObjectPool ( C, Args ... ) : ObjectPoolImpl
{
    alias .PoolItem PoolItemInterface;
    
    /***************************************************************************

        PoolItem class: C subclass that can recycle itself. 
    
    ***************************************************************************/

    class PoolItem : C
    {
        /***********************************************************************

            Constructor
            
             Params:
                 args = C constructor arguments
        
        ***********************************************************************/

        static if (Args.length) this (Args args) {super(args);}
        
        /***********************************************************************

            Returns this instance back to the pool.
        
        ***********************************************************************/

        final void recycle ( ) {this.outer.recycle(this);}
    }
    
    /***************************************************************************

        CustomPoolItem class: PoolItem subclass that implements
        PoolItem. If C (and therefore PoolItem) already implements
        PoolItem, CustomPoolItem is an alias for PoolItem.
    
    ***************************************************************************/

    static if (is (PoolItem : PoolItemInterface))
    {
        alias PoolItem CustomPoolItem;
    }
    else
    {
        final class CustomPoolItem : PoolItem, PoolItemInterface
        {
            /**********************************************************************
                
                Value to memorize
                
            ***********************************************************************/
            
            private uint object_pool_index_;
            
            /**********************************************************************
            
                Memorizes n.
                
                Params:
                    n = value to memorize
                
            ***********************************************************************/
            
            uint object_pool_index ( ) {return this.object_pool_index_;}
            
            /**********************************************************************
            
                Returns the value that was previously passed as parameter to 
                object_pool_index(uint).
                
                 Returns:
                     the value that was previously passed as parameter to
                     object_pool_index(uint)
            
             **********************************************************************/
        
            void   object_pool_index ( uint n ) {this.object_pool_index_ = n;}
            
            /**********************************************************************
    
                Constructor
                
                 Params:
                     args = C constructor arguments
            
             **********************************************************************/
    
            static if (Args.length) this (Args args) {super(args);}
        }
    }
    
    /************************************************************************** 

        C constructor arguments to be used each time an object is created
    
     **************************************************************************/
    
    static if (Args.length) private Args args;

    /************************************************************************** 

        Constructor
        
        Params:
            args = C constructor arguments to be used each time an object is
                   created
    
     **************************************************************************/

    this ( Args args )
    {
        static if (Args.length)
        {
            this.args = args;
        }
    }
    
    /************************************************************************** 

        Gets an object from the object pool.
        
        Returns:
            object from the object pool
    
     **************************************************************************/

    PoolItem get ( )
    out (item)
    {
        assert (item !is null);
    }
    body
    {
        return cast (CustomPoolItem) super.get(this.newItem());
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

    public C opIndex ( uint n )
    out (item)
    {
        assert (item !is null);
    }
    body
    {
        return cast (C) super.opIndex(n);
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
    
        'foreach' iteration over busy pool items
        
        Caution: The items iterated over must not be recycled; changing them has
        no effect. During iteration only opIndex(), opApply() and length() may
        be called.

    **************************************************************************/

    public int opApply ( int delegate ( ref C item ) dg )
    {
        return super.opApply((ref Object obj)
                             {
                                 auto item = cast (C) obj;
                                 
                                 assert (item !is null);
                                 
                                 return dg(item);
                             });
    }
    
    /**************************************************************************
    
        Creates a new ObjectPool instance.
        
        Params:
            args = C constructor arguments to be used each time an object is
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
    
    protected PoolItemInterface newItem ( )
    {
        static if (Args.length)
        {
            return this.new CustomPoolItem(args);
        }
        else
        {
            return this.new CustomPoolItem;
        }
    }

}

/*******************************************************************************

    Actual object pool implementation

*******************************************************************************/

class ObjectPoolImpl : IObjectPoolInfo
{
    /**************************************************************************
    
        Convenience This alias
    
     **************************************************************************/

    private alias typeof (this) This;
    
    /**************************************************************************
    
        Magic limit value indicating no limitation
    
     **************************************************************************/

    public const uint unlimited = uint.max;
    
    /**************************************************************************
    
        May be set to true at any time to limit the number of items in pool to
        the current number or to false to disable limitation.
    
     **************************************************************************/

    public bool limited = false;
    
    /**************************************************************************
    
        List of items (objects) in pool, busy items first
    
     **************************************************************************/

    private PoolItem[] items;
    
    /**************************************************************************
    
        Number of busy items in pool
    
     **************************************************************************/

    private uint num_busy_ = 0;
    
    /**************************************************************************
    
        Reused exception instance
    
     **************************************************************************/

    private LimitExceededException limit_exception;
    
    /*************************************************************************/
    
    invariant
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
            
            new_item = expression that creates a new PoolItem instance
            
        Returns:
            limit
        
        Throws:
            LimitExceededException if the number of busy pool items exceeds
            the desired limit
        
     **************************************************************************/
    
    uint limit ( uint limit, lazy PoolItem new_item )
    out
    {
        foreach (item; this.items)
        {
            assert (item !is null);
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
                this.resetItem(cast (Resettable) item);
                
                delete item;
                
                item = null;
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
            new_item = expression that creates a new PoolItem instance
        
        Returns:
            pool item

        Throws:
            LimitExceededException if limitation is enabled and all pool items
            are busy
        
    **************************************************************************/

    public Object get ( lazy PoolItem new_item )
    out (obj)
    {
        PoolItem item_out = cast (PoolItem) obj;
        
        assert (item_out !is null);
        
        assert (item_out is this.items[this.num_busy_ - 1]);
        
        debug (ObjectPoolConsistencyCheck)
        {
            foreach (item; this.items[0 .. this.num_busy_ - 1])
            {
                assert (item !is item_out);
            }
            
            if (this.num_busy_ < this.items.length) foreach (item; this.items[this.num_busy_ + 1 .. $])
            {
                assert (item !is item_out);
            }
        }
    }
    body
    {
        PoolItem item;
        
        if (this.num_busy_ < this.items.length)
        {
            item = this.items[this.num_busy_];
            
            assert (item !is null);
        }
        else
        {
            this.limit_exception.check(false, "all available items are busy", __FILE__, __LINE__);
            
            item = new_item();
            
            this.items ~= item;
            
            assert (item !is null);
        }
        
        item.object_pool_index = this.num_busy_++;
        
        return cast (Object) item;
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

    public Object opIndex ( uint n )
    out (obj)
    {
        assert (obj !is null);
    }
    body
    {
        return cast (Object) this.items[n];
    }
    
    /**************************************************************************
    
        Puts item back to the pool.
        
        Params:
            item = item to put back
        
        Returns:
            this instance
        
        Throws:
            LimitExceededException if there are busy object pool items

    **************************************************************************/

    public This recycle ( Object obj )
    in
    {
        assert (this.num_busy_, "nothing is busy so there is nothing to recycle");
        
        PoolItem item_in = cast (PoolItem) obj;
        
        assert (item_in !is null, "recycled object is not a PoolItem");
        
        assert (item_in.object_pool_index < this.items.length,
                "index of recycled item out of range");
        
        assert (item_in is this.items[item_in.object_pool_index],
                "wrong index in recycled item");
        
        assert (item_in.object_pool_index < this.num_busy_,
                "recycled item is idle");
    }
    body
    {
        PoolItem item_in = cast (PoolItem) obj;
        
        PoolItem* item            = this.items.ptr + item_in.object_pool_index,
                  first_idle_item = this.items.ptr + --this.num_busy_;
        
        this.resetItem(cast (Resettable) item_in);
        
        *item = *first_idle_item;
        
        *first_idle_item = item_in;
        
        item.object_pool_index = item_in.object_pool_index;
        
        first_idle_item.object_pool_index = this.num_busy_;
        
        return this;
    }
    
    /**************************************************************************
    
        Recycles all items in the pool.
        
        Returns:
            this instance
        
    **************************************************************************/

    public This clear ( )
    {
        this.num_busy_ = 0;
        
        return this;
    }
    
    /***************************************************************************
    
        'foreach' iteration method over the active items in the pool.
        
        Caution: The items iterated over must not be recycled; changing them has
        no effect. During iteration only opIndex(), opApply() and length() may
        be called.

    ***************************************************************************/

    public int opApply ( int delegate ( ref Object obj ) dg )
    {
        int ret;

        foreach ( ref item; this.items[0 .. this.num_busy_] )
        {
            auto obj = cast (Object) item;
            
            ret = dg(obj);
            if ( ret )
            {
                break;
            }
        }

        return ret;
    }
    
    /***************************************************************************
    
        Calls item.reset() if item is not null.
        
        Params:
            item = resettable object pool item or null
        
    ***************************************************************************/

    private static void resetItem ( Resettable item )
    {
        if (item !is null)
        {
            item.reset();
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
    
*******************************************************************************/

debug ( OceanUnitTest )
{
    class MyClass : Resettable
    {
        private char[] name;
        private void delegate() callOnDeath,callOnReset;   
        
        
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
    import ocean.util.Profiler;
    import tango.io.FilePath; 
    
    unittest
    { 
        /***********************************************************************
            
            General testing of most functions and behavior
            
        ***********************************************************************/   
        
        {   
            Trace.formatln("ObjectPool: Running general unittest");
            bool reset=false,death = false;
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
                assert(tmp.getNumItems == 1);
            }
            
            scope pool1 = new ObjectPool!(MyClass, char[], 
                                          void delegate(),void delegate())
                                          ("one" , &deathFunc,&resetFunc);
            
            
            // Test limit related query/set functions
            assert(pool1.limited == false);
            
            pool1.limited(true);                 
            assert(pool1.limited == true);
            
            pool1.limited(false);
            assert(pool1.limited == false);
            
            pool1.limit(5);
            assert(pool1.limited);
            assert(pool1.limit == 5);            
            
            auto a = pool1.get();
            
            auto b = pool1.get();            
            b.recycle();
            assert(pool1.getNumIdleItems == 1);   
            assert(pool1.getNumItems == 2);
            
            auto c = pool1.get();            
            pool1.recycle(cast(MyClass)c);            
            assert(pool1.getNumItems == 2);            
            
            auto d = pool1.get();            
            {
                reset = death = false;
                
                pool1.remove(d);
                
                assert(death,"Death should be set");                
                assert(reset,"Reset should be set");
                assert(pool1.getNumItems == 1);
                
                death = reset = false;
            }
            
            assert(pool1.limit == 5);
            
            d = pool1.get();
            assert(pool1.getNumItems == 2);
            
            auto e = pool1.get();
            
            // Test setting a to small limit
            {
                auto catched = false;
                
                try pool1.limit(1);
                catch (ObjectPoolException e) catched = true;
                
                assert(catched);
            }
            
            assert(pool1.limit == 5);
            
            // Test requesting to much items
            {
                auto catched = false;
                
                try pool1.setNumItems(6);
                catch (ObjectPoolException e) catched = true;
                
                assert(catched);
            }     
            
            assert(pool1.limit == 5);
           
            
            pool1.setNumItems(5);
            
            assert(pool1.getNumItems == 5);
            
            c = pool1.get();
            d = pool1.get();
  
            assert (pool1.getNumItems == 5);
            
            
            // Test limit            
            {
                auto catched = false;
                
                try
                {
                    auto fail = pool1.get();
                }
                catch (ObjectPoolException e)
                {
                    catched = true;
                }
                
                assert (catched);
                
            }
            
            pool1.limit(6);
            assert(pool1.limit ==6 && pool1.max == 6);
            auto f = pool1.get();
            
            assert (pool1.getNumItems == 6);
            assert (pool1.getNumIdleItems == 0);
            assert (pool1.getNumBusyItems == 6);
            assert (pool1.getNumAvailableItems == 0);                       
            
            pool1.recycle(a);

            assert (pool1.getNumItems == 6);
            assert (pool1.getNumIdleItems == 1);
            assert (pool1.getNumBusyItems == 5);
            assert (pool1.getNumAvailableItems == 1);
            
            pool1.setNumItems(5);
            
            assert (pool1.getNumItems == 5);
            assert (pool1.getNumIdleItems == 0);
            assert (pool1.getNumBusyItems == 5);
            assert (pool1.getNumAvailableItems == 1);
            
            assert(c==c);
            assert(c<d);
            
            class Tmp {};
            scope bigger = new Tmp();
            assert(c<bigger);  
        } 
        Trace.formatln("Test finished");
    }    
}

/*******************************************************************************
    
    Constructs a new pool, takes the first c'tor automatically.    
    
        Template Params:
            T = type of object to construct
            A = (optional) list of argument types for the c'tor. If non-type
                values will be passed, takes the default constructor
                
         Params:
             args = arguments for the constructor of the newly created object
    
*******************************************************************************/
     
version (none) public ObjectPool!(T,A) newAutoPool(T, A ...) ( A args )
{
    static if(A.length == 0)
    {
        alias ParameterTupleOf!(typeof(&T._ctor)) A;
    }
    else static if(!is(A))        
    {        
        alias Tuple!() A;
    }
    return new ObjectPool!(T,A)(args);
} 
     
    
    