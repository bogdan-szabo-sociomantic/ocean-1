/******************************************************************************

    Manages a pool of threads and class instances where each thread refers to
    the run() method of a class. 

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2010: Initial release

    authors:        David Eckardt

    The ObjectThreadPool class is derived from tango.core.ThreadPool and manages
    a pool of threads and class instances where each thread refers to the run()
    method of a class.

    
    The class that should be managed by ObjectThreadPool must contain a public
    run() method. run() may accept any number and types of arguments and must
    return void. run() should not be overloaded.
    
    Usage:
    
    To use ObjectThreadPool together with a class MyClass, MyClass and its
    constructor argument types, if any, must be passed as ObjectThreadPool class
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
    
    , the ObjectThreadPool class template instantiation would be
    
    ---
    
        ObjectThreadPool!(MyClass, int, char[])
    
    ---
    
    because the constructor of MyClass takes the int argument 'ham' and the
    char[] argument 'eggs'.
    
    The constructor of ObjectThreadPool the arguments for the constructor of
    MyClass, followed by the number of worker threads (size_t workers) and an
    optional queue size parameter (size_t q_size).
    
    Hence, an ObjectThreadPool instance for MyClass as defined above is created
    by
    
    ---
        
        import $(TITLE)
        
        const WORKERS = 4;
        
        int    x = 42;
        char[] y = "Hello World!";
        
        ObjectThreadPool!(MyClass, int, char[]) pool;
        
        pool = new ObjectThreadPool!(MyClass, int, char[])(x, y, WORKERS);
    
    ---
    
    Since the "new ObjectThreadPool ..." part is quite long, the
    ObjectThreadPool class provides the newPool() factory method for
    convenience:
    
    ---
        
        import $(TITLE)
        
        const WORKERS = 4;
        
        int    x = 42;
        char[] y = "Hello World!";
        
        ObjectThreadPool!(MyClass, int, char[]) pool;
        
        pool = pool.newPool(x, y, WORKERS);
    
    ---
    
    A thread is started by invoking the assign() method of ObjectThreadPool.
    assign() takes the arguments for MyClass.run(). The complete example is:
    
    ---
        
        import $(TITLE)
        
        // Define MyClass
        
        class MyClass
        {
            this ( int ham, char[] eggs )
            { ... }
            
            void run ( float spam, bool sausage )
            { ... }
        }
        
        // Create ObjectThreadPool instance for MyClass
        
        const WORKERS = 4;
        
        int    x = 42;
        char[] y = "Hello World!";
        
        ObjectThreadPool!(MyClass, int, char[]) pool;
        
        pool = pool.newPool(x, y, WORKERS);
        
        // Start a new thread; this will invoke MyClass.run()
        
        float a;                // passed to argument 'spam' of MyClass.run()
        bool  b;                // passed to argument 'sausage' of MyClass.run()
        
        pool.assign(a, b);
        
    ---
            
 ******************************************************************************/

module ocean.core.ObjectThreadPool;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.core.ObjectPool;

private import tango.core.ThreadPool;

/******************************************************************************

    ObjectThreadPool class template
    
    Params:
        T      = type of items in pool; must be a class
        Ctypes = types of constructor arguments of class T

 ******************************************************************************/

class ObjectThreadPool ( T, Ctypes ... ) : ThreadPool!(RunArgTypes!(T))
{
    /**************************************************************************
    
        Convenience This and OPool alias
    
     **************************************************************************/

    private alias typeof (this) This;
    
    private alias ObjectPool!(T, Ctypes) OPool;
    
    /**************************************************************************
    
        Re-derive tuple of run() argument types: Rtypes
    
     **************************************************************************/
    
    static if (is (typeof (super.assign) Types == function))
    {
        alias Types[1 .. $] Rtypes;
    }
    
    /**************************************************************************
    
        Object pool
    
     **************************************************************************/
    
    private OPool pool;
    
    
    /**************************************************************************
     
         Constructor
     
         Params:
             args    = T constructor arguments 
             workers = number of worker threads (passed to
                       tango.core.ThreadPool constructor)
             q_size  = initial thread queue size (passed to
                       tango.core.ThreadPool constructor)
         
     **************************************************************************/
    
    public this ( Ctypes args, size_t workers, size_t q_size = 0 )
    {
        super(workers, q_size);
        
        this.pool = new OPool(args);
        
        this.pool.setNumItems(workers);
    }
    
    /**************************************************************************
    
        Starts T.run() in an own thread, if an idle thread is available from
        the thread pool, or blocks until one is available.
        
        Params:
            args = arguments to pass to T.run()
            
        Returns:
            this instance
    
     **************************************************************************/
    
    public This assign ( Rtypes args )
    {
        super.assign(&this.runItem, args);
        
        return this;
    }
    
    /**************************************************************************
    
        Starts T.run() in an own thread, if an idle thread is available from
        the thread pool.
        
        Params:
            args = arguments to pass to T.run()
            
        Returns:
            true if an idle thread was available and therefore was started or
            false otherwise
    
     **************************************************************************/
    
    public bool tryAssign ( Rtypes args )
    {
        return super.tryAssign(&this.runItem, args);
    }
    
    /**************************************************************************
    
        Increases the thread pool by one element.
        
        Params:
            args = arguments to pass to T.run()
            
        Returns:
            this instance
    
     **************************************************************************/

    public This append ( Rtypes args )
    {
        super.append(&this.runItem, args);
        
        return this;
    }
    
    /**************************************************************************
    
        Picks an item from the objecct pool, invokes run() and puts it back.
        This is the actual thread method.
        
        Params:
            args = arguments to pass to T.run()
    
     **************************************************************************/

    private void runItem ( Rtypes args )
    {
        OPool.PoolItem item = this.pool.get();
        
        item.run(args);
        
        this.pool.recycle(item);
    }
    
    /**************************************************************************
    
        Factory method; creates a pool instance
        
        Params:
            args = default arguments to pass to constructor on pool item creation
    
        Returns:
            new pool instance
    
    **************************************************************************/
    
    public static This newPool ( Ctypes args, size_t workers, size_t q_size = 0 )
    {
        return new This(args, workers, q_size);
    }
}

/******************************************************************************

    RunArgTypes template
    
    Checks T for a run() property

 ******************************************************************************/

private template RunArgTypes ( T )
{
    static assert (is (typeof (T.run)), "no run() method in '" ~ T.stringof ~ "' class");
    
    static if (is (typeof (T.run) Types == function))
    {
        alias Types RunArgTypes;
    }
}
