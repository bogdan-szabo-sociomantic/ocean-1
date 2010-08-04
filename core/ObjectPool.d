/******************************************************************************

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
   
 ******************************************************************************/

module ocean.core.ObjectPool;

/*******************************************************************************

	Imports

*******************************************************************************/

private import ocean.core.Exception: ObjectPoolException, assertEx;

debug private import tango.util.log.Trace;



/******************************************************************************
  
    ObjectPool class template
    
    Params:
        T = type of items in pool; must be a class
        A = types of constructor arguments of class T
   
 ******************************************************************************/

class ObjectPool ( T, A ... )
{
    /**************************************************************************
    
        Convenience This alias
    
     **************************************************************************/

    private alias typeof (this) This;
    
    /**************************************************************************
    
        Ensure T is a class
    
     **************************************************************************/

    static assert (is (T == class), This.stringof ~ ": Object type must be a "
                                    "class, not '" ~ T.stringof ~ "'");
    
    private const CLASS_ID_STRING = This.stringof ~ '(' ~ T.stringof ~ ')';
    
    /**************************************************************************
    
        Information structure for a single item

     **************************************************************************/

    private struct ItemInfo
    {
        bool idle;
    }
    
    /**************************************************************************
    
        Maximum number of items in pool if limitation enabled 
    
     **************************************************************************/
    
    public size_t max;

    /**************************************************************************
    
        List of items: Associative array of information structure with item
                       instance as index.
                       The PoolItem class is derived from the supplied T class;
                       its only purpose is to override some methods of the
                       Object class which is necessary in order to use PoolItem
                       as an associative array index type. Hence it is safe to
                       think of PoolItem as an alias of T.
                       The PoolItem class definition is at the end of this
                       class.
    
     **************************************************************************/

    private ItemInfo[PoolItem] items;
    
    /**************************************************************************
    
        Serial number as unique identifier for pool items. As the PoolItem class
        this is required in order to build the associative array and counted up
        on each item creation.
    
     **************************************************************************/
    
    private hash_t serial;

    /**************************************************************************
    
        true: Allow at most "max" items in pool
    
     **************************************************************************/
    
    private bool   limited_;
    
    /**************************************************************************
    
        Default constructor arguments for pool item creation
    
     **************************************************************************/
    
    private A      args;
    
    /**************************************************************************
    
        Constructor
        
        Params:
            args = default arguments to pass to constructor on pool item creation
    
    **************************************************************************/

    public this ( A args )
    {
        this.serial = cast (hash_t) &this;
        
        this.setArgs(args);
    }
    
    
    /**************************************************************************
    
        Factory method; creates a pool instance
        
        Params:
            args = default arguments to pass to constructor on pool item creation
    
        Returns:
            new pool instance
    
    **************************************************************************/
   
    public static This newPool ( A args )
    {
        return new This(args);
    }
    
    /**************************************************************************
        
        Takes an idle item from the pool or creates a new one if all item are
        busy or the pool is empty.
        
        Params:
            args = arguments to pass to constructor on pool item creation
        
        Returns:
            pool object
        
    **************************************************************************/

    public PoolItem get ( A args )
    {
        foreach (item, ref info; this.items)
        {
            if (info.idle)
            {
                info.idle = false;
                
                item.recycling = false;
                
                return item;
            }
        }
        
        return this.create(args);
    }
    
    /**************************************************************************
    
        ditto
        
     **************************************************************************/
    
     // "static if" avoids collision of overloaded method in case of empty "A".
    
    static if (A.length)
    {
        public PoolItem get ()
        {
            return this.get(this.args);
        }
    }
    
    /**************************************************************************
    
        Puts item back to the pool.
        
        Params:
            item = item to put back
        
        Returns:
            this instance
        
    **************************************************************************/

    public This recycle ( PoolItem item )
    {
        this.recycle_(item);
        
        return this;
    }
    
    public This recycle ( T item )
    {
        return this.recycle(cast (PoolItem) item);
    }
    
    /**************************************************************************
    
        Removes item from pool and deletes it.
        
        Params:
            item = item remove
        
        Returns:
            this instance
        
    **************************************************************************/

    public This remove ( PoolItem item )
    {
        scope (success) this.removeItem(item);
        
        return this.recycle(item);
    }
    
    /**************************************************************************
    
        Enables/disables limitation of number of items in pool.
        
        Params:
            limited_ = true enables, false disables limitation
        
        Returns:
            this instance
        
    **************************************************************************/
    
    public This limited ( bool limited_ )
    {
        this.limited_ = limited_;
        
        this.checkLimit("too many items in pool");
        
        return this;
    }
    
    /**************************************************************************
    
        Returns limitation state.
        
        Returns:
            true if limitation is enabled or false otherwise
        
    **************************************************************************/

    public bool limited ( )
    {
        return this.limited_;
    }
    
    /**************************************************************************
    
	    Enables item count limitation, and sets the maximum number of items.
	    
	    Params:
	        max_items = max items allowed in pool
	    
	    Returns:
	        this instance
	    
	**************************************************************************/

    public This limit ( size_t max_items )
    in
    {
        assert (max_items, This.stringof ~ ".limit: limit set to 0");
    }
    body
    {
    	this.limited_ = true;
    	this.max = max_items;

    	this.checkLimit("too many items in pool");
        
        return this;
    }
    
    /**************************************************************************
    
        Returns the limit of items in pool
        
        Returns:
            limit of items in pool
        
    **************************************************************************/

    public size_t limit ( )
    {
        return this.max;
    }
    
    /**************************************************************************
    
        Sets the number of items in pool.
        
        To achieve this, as many items as required are created or removed.
        If more items are busy than required to be removed, all idle items are
        removed and an exception is thrown.
        If the requested number of items exceeds the limit, the number of items
        is set to the limit and an exception is thrown.
        
        Params:
            n    = nominate number of values
            args = arguments to pass to constructor on pool item creation 
        
        Returns:
            this instance
        
    **************************************************************************/
    
    /*
     * Wrapping of setNumItems_ is necessary to avoid compiler errors if "A" is
     * empty.
     */
    
    public This setNumItems ( size_t n, A args )
    {
        return this.setNumItems_(n, args);
    }
    
    /**************************************************************************
    
        ditto
        
     **************************************************************************/
    
    // "static if" avoids collision of overloaded method in case of empty "A".
    
    static if (A.length)
    {
        public This setNumItems ( size_t n )
        {
            return this.setNumItems_(n, this.args);
        }
        
    }
    
    /**************************************************************************
    
        Returns the number of items in pool.
        
        Returns:
            the number of items in pool
        
     **************************************************************************/

    public size_t getNumItems ( )
    {
        return this.items.length;
    }
    
    
    /**************************************************************************
    
        Returns the number of idle items in pool.
        
        Returns:
            the number of idle items in pool
        
     **************************************************************************/

    public size_t getNumIdleItems ( )
    {
        size_t result = 0;
        
        foreach (info; this.items)
        {
            result += info.idle;
        }
        
        return result;
    }
    
    /**************************************************************************
    
        Returns the number of busy items in pool.
        
        Returns:
            the number of busy items in pool
        
     **************************************************************************/

    public size_t getNumBusyItems ( )
    {
        return this.items.length - this.getNumIdleItems();
    }
    
    /**************************************************************************
    
	    Returns the number of items available from pool. This is a reasonable
	    value only if the total number of pool items is limited.
	    
	    Returns:
	        the number of items available from pool
	    
	 **************************************************************************/
	
	public size_t getNumAvailableItems ( )
	{
	    return this.limited? this.max - this.getNumBusyItems() : size_t.max;
	}

	/**************************************************************************
    
        Sets the default constructor arguments for item creation.
        
        Params:
            args = default constructor arguments for item creation
        
        Returns:
            this instance
        
     **************************************************************************/

    public This setArgs ( A args )
    {
        static if (A.length) this.args = args;
        
        return this;
    }
    
    /**************************************************************************
    
        Sets the number of items in pool.
        
        To achieve this, as many items as required are created or removed.
        If more items are busy than required to be removed, all idle items are
        removed and an exception is thrown.
        If the requested number of items exceeds the limit, the number of items
        is set to the limit and an exception is thrown.
        
        Params:
            n    = nominate number of values
            args = arguments to pass to constructor on pool item creation 
        
        Returns:
            this instance
        
    **************************************************************************/
    
    /*
     *  "B" is required in order to work if "A" is empty and therefore "args"
     *  is void.
     */    
    
    private This setNumItems_ ( B ... ) ( size_t n, B args )
    {
        static assert (is (B == A), This.stringof ~ ".setNumItems_(): "
                                    "must be called with arguments of types " ~
                                    typeof (this.args).stringof ~ " not " ~
                                    typeof (args).stringof);
        
        if (this.limited_ && (n > this.max))
        {
            n = this.max;
        }
        
        if (n < this.items.length)
        {
            size_t remaining = this.items.length - n;
            
            foreach (item, info; this.items)
            {
                if (info.idle)
                {
                    this.removeItem(item);
                    
                    if (!--remaining) break;
                }
            }
            
            assertEx!(ObjectPoolException)(!remaining, This.stringof ~ ": more pool items busy than requested number");
        }
        else
        {
            for (size_t i = this.items.length; i < n; i++)
            {
                this.create(args, true);
            }
        }
        
        this.checkLimit("requested number of items exceeds limit");
        
        return this;
    }
    /**************************************************************************
    
        Checks whether the number of items in pool is less or equal
        (less == false) or is less (less == true) than the limit and throws an
        exception if not.
        
        Params:
            msg  = exception message
            less = true:  number of items in pool must be less than max;
                   false: number of items in pool must be less than or equal to
                          max
        
    **************************************************************************/

    private void checkLimit ( char[] msg, bool less = false )
    {
        assertEx!(ObjectPoolException)(this.items.length + less <= this.max || !this.limited_,
                                       This.stringof ~ ": " ~ msg);
    }
    
    private void removeItem ( PoolItem item )
    {
        delete item;
        
        this.items.remove(item);
    }
    
    /**************************************************************************
    
        Puts item back to the pool.
        
        Params:
            item = item to put back
            
    **************************************************************************/
    
    private void recycle_ ( PoolItem item )
    {
        assertEx!(ObjectPoolException)(item in this.items, this.CLASS_ID_STRING ~ ": recycled item not registered");
        
        this.items[item].idle = true;
    }

    /**************************************************************************
    
        Creates a pool item with idle status idle.
        
        Params:
            args = pool item constructor arguments
            idle = idle status of new pool item
        
        Returns:
            new pool item
        
    **************************************************************************/

    private PoolItem create ( A args, bool idle = false )
    {
        this.checkLimit("no more items available", true);

        this.serial++;
        
        PoolItem item = new PoolItem(serial, &this.recycle_, args);
        
        this.items[item] = ItemInfo(idle);
        
        return item;
    }
    
    /**************************************************************************
     
         Destructor
     
     **************************************************************************/
    
    private ~this ( )
    {
        foreach (item, info; this.items)
        {
            delete item;
        }
        
        this.items = this.items.init;
    }

    /**************************************************************************
         
         PoolItem class
         
         According to the D specification, a class used as associative array
         index shall override toHash(), opEquals() and opCmp(). The PoolItem
         class extends the supplied class T in this manner. Comparison and hash
         use the same private "hash" property whose value is supplied on
         instantiation.
      
     **************************************************************************/
     
    private class PoolItem : T
    {
        /**********************************************************************
        
            Recycler callback type alias
        
        **********************************************************************/
        
        private alias void delegate ( typeof (this) ) Recycler;
        
        /**********************************************************************
        
            Recycler callback
        
        **********************************************************************/
        
        private Recycler recycle_;
        
        /**********************************************************************
        
            recycling/recycled properties and invariant: Throws an exception if
            any public method of this or super is called after recycle().
        
         **********************************************************************/
        
        private bool recycling = false;
        
        invariant
        {
            assert (!this.recycling, T.stringof ~ ": attempted to use idle item");
        }
        
        /**********************************************************************
         
            Hash value, also used for comparison (opCmp())
          
         **********************************************************************/
        
        private hash_t hash;
        
        /**********************************************************************
         
             Constructor
             
             Params:
                 hash    = hash value
                 recycle = method to call to put this instance back into pool
                 args    = super class constructor arguments
         
         **********************************************************************/
        
        this ( hash_t hash, Recycler recycle, A args )
        {
            static if (A.length)
            {                   // explicitely invoke super constructor only if
                super(args);    // arguments are to be passed to it
            }
            
            this.hash = hash;
            
            this.recycle_ = recycle;
        }
        
        
        /**********************************************************************
        
            Puts this instance back into the pool it was taken from.
        
        **********************************************************************/
        
        void recycle ( )
        {
            this.recycle_(this);
        }
        
        /**********************************************************************
        
            Returns the hash value.
            
            Returns:
                the hash value
        
        **********************************************************************/
       
        hash_t toHash()
        {
            return this.hash;
        }
        
        /**********************************************************************
        
            Checks this instance for identitiy to obj.
            
            Returns:
                true if obj is identical to this instance or false otherwise
        
        **********************************************************************/
       
        int opEquals(Object obj)
        {
            return this is obj;
        }
        
        /**********************************************************************
        
            Compares this instance to obj.
            
            Returns:
                - 0 if if obj is identical to this instance,
                - the difference between the hashes of this instance and obj
                  if comparison in this manner is possible or
                - the least possible value otherwise.
        
        **********************************************************************/
       
        int opCmp(Object obj)
        {
            if (this.opEquals(obj)) return 0;
            
            auto item = cast (typeof (this)) obj;
            
            if (item)
            {
                return cast (int) (this.toHash() - item.toHash());
            }
            else
            {
                return int.min;
            }
        }
    } // PoolItem
}