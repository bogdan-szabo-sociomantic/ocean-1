/******************************************************************************

        Manages a pool of objects
    
        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
        version:        Jan 2010: Initial release
    
        authors:        David Eckardt

        Usage:
        
        ---
        
            import $(TITLE)
            
            // The items in pool will be of MyClass:
            
            class MyClass
            {
                this ( int ham, char[] eggs, bool sausage )
                { ... }
            }
            
            // Create an ObjectPool instance managing objects of "MyClass". The
            // template parameters for ObjectPool!() are therefore "MyClass"
            // followed by the types of the constructor arguments of "MyClass".
            
            ObjectPool pool = new ObjectPool!(MyClass, int, char[], bool);
            
            // Call pool.get() to get an item from "pool", passing the "MyClass"
            // constructor parameters.
            
            MyClass item = pool.get(42, "Hello world!", true);
            
        ---

 ******************************************************************************/

module mem.ObjectPool;

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
    
    private bool   limited;
    
    /**************************************************************************
    
        Default constructor arguments for pool item creation
    
     **************************************************************************/
    
    private A      args;
    
    /**************************************************************************
     
         Constructor
     
     **************************************************************************/
    
    public this ( )
    {
        this.serial = cast (hash_t) &this;
    }
    
    /**************************************************************************
    
        Constructor; creates n initial pool items.
        
        Params:
            n    = number of initial pool items
            args = arguments to pass to constructor on pool item creation
    
    **************************************************************************/

    public this ( uint n, A args )
    {
        this();
        
        this.setArgs(args);
        
        for (uint i = 0; i < n; i++)
        {
            this.create(args, true);
        }
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
        public PoolItem get ( )
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

    public This back ( PoolItem item )
    {
        assert (item in this.items, This.stringof ~ ": item returned not registered");
        
        this.items[item].idle = true;
        
        return this;
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
        
        return this.back(item);
    }
    
    /**************************************************************************
    
        Enables/disables limitation of number of items in pool.
        
        Params:
            limited = true enables, false disables limitation
        
        Returns:
            this instance
        
    **************************************************************************/
    
    public This limit ( bool limited )
    {
        this.limited = limited;
        
        this.checkLimit("too many items in pool");
        
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
     * Wrapping of _setNumItems is necessary to avoid compiler errors if "A" is
     * empty.
     */
    
    public This setNumItems ( size_t n, A args )
    {
        return this._setNumItems(n, args);
    }
    
    /**************************************************************************
    
        ditto
        
     **************************************************************************/
    
    // "static if" avoids collision of overloaded method in case of empty "A".
    
    static if (A.length)
    {
        public This setNumItems ( size_t n )
        {
            return this._setNumItems(n, this.args);
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
     *  "B" is required in order to work if "A" and consequently "args" is
     *  empty.
     */    
    
    private This _setNumItems ( B ... ) ( size_t n, B args )
    {
        static assert (is (B == A), This.stringof ~ "._setNumItems(): "
                                    "must be called with arguments of types " ~
                                    typeof (this.args).stringof ~ " not " ~
                                    typeof (args).stringof);
        
        if (this.limited && (n > this.max))
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
            
            assert (!remaining, This.stringof ~ ": more pool items busy than requested number");
        }
        else
        {
            for (size_t i = this.items.length; i < n; i++)
            {
                this.create(args);
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
        assert (this.items.length + less <= this.max || !this.limited,
                This.stringof ~ ": " ~ msg);
    }
    
    private void removeItem ( PoolItem item )
    {
        delete item;
        
        this.items.remove(item);
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
        const name = args.stringof;
        
        const newItem = "new " ~ this.PoolItem.stringof ~   // creates "new PoolItem(serial, args[0], args[1], ...)"
                        '(' ~ this.serial.stringof ~ this.arglist!("args", A) ~ ')';
        
        pragma (msg, newItem);
        
        this.checkLimit("no more items available", true);
        
        this.serial++;
        
        PoolItem item = mixin (newItem);
        
        this.items[item] = ItemInfo(idle);
        
        return item;
    }
    
    /**************************************************************************
    
        PoolItem instantiation argument list templates
    
     **************************************************************************/
    
    /**************************************************************************
    
        Generates the argument list for the tuple "name" of arguments with types
        of tuple "A" with a leading ',' if "A" is not empty.
        "A" is merely used to determine the argument list length.
        
        Example:
        
        ---
            
            const list = arglist!("x", int, char[], bool);
            
            // "list" now holds "x[0],x[1],x[2]"
            
        ---
    
        Params:
            name = name of the tuple of arguments
            A    = tuple of argument types
            
        Returns:
            generated argument list string
        
     **************************************************************************/

    private template arglist ( char[] name, A ... )
    {
        static if (A.length)
        {
            const arglist = arglist!(",", 0, name, A);
        }
        else
        {
            const arglist = "";
        }
    }
    
    /**************************************************************************
    
        Generates the argument list for the tuple "name" of arguments with types
        of tuple "A", starting with index "i", and appends the list to "list".
        "A" is merely used to determine the number of arguments.
        
        Example:
        
        ---
            
            const list = arglist!("items_before", 3, "x", int, char[], bool);
            
            // "list" now holds "items_before,x[3],x[4],x[5]"
            
        ---
    
        Params:
            list = list to append generated list
            i    = start index
            name = name of the tuple of arguments
            A    = tuple of argument types
            
     **************************************************************************/

    private template arglist ( char[] list, int i, char[] name, A ... )
    {
        static if (A.length > 1)
        {
            const arglist = appendArg!(list, i, name) ~ ',' ~ arglist!(list, i + 1, name, A[1 .. $]);
        }
        else
        {
            const arglist =  appendArg!(list, i, name);
        }
    }
    
    /**************************************************************************
    
        Generates an argument list item for the tuple "name" of arguments with
        index "i" and appends the item to "list".
        
        Example:
        
        ---
            
            const list = appendArg!("item_before", 42, "x");
            
            // "list" now holds "item_beforex[42]"
            
        ---
    
        Params:
            list = list to append generated item
            i    = item index
            name = name of the tuple of items
        
    **************************************************************************/
    
    private template appendArg ( char[] list, int i, char[] name )
    {
        const appendArg = list ~ name ~ '[' ~ i.stringof ~ ']';
    }
    
    /**************************************************************************
     
         Destructor
     
     **************************************************************************/
    
    ~this ( )
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
         
            Hash value, also used for comparison
          
         **********************************************************************/
        
        private hash_t hash;
        
        /**********************************************************************
         
             Constructor
             
             Params:
                 hash = hash value
                 args = super class constructor arguments
         
         **********************************************************************/
        
        this ( hash_t hash, A args )
        {
            super(args);
            
            this.hash = hash;
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