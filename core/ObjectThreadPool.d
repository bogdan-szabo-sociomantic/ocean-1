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
    
    The constructor of ObjectThreadPool expects the arguments for the 
    constructor of MyClass, followed by the number of worker threads 
    (size_t workers) and an optional queue size parameter (size_t q_size).
    
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



/*******************************************************************************

    Imports
    
*******************************************************************************/

private import ocean.core.Exception;

private import ocean.core.ObjectPool;

private import tango.core.ThreadPool;


debug
{
	private import tango.util.log.Trace;
}



/******************************************************************************

    ObjectThreadPool class template
    
    Params:
        T      = type of items in pool; must be a class
        Args = types of constructor arguments of class T

 ******************************************************************************/

class ObjectThreadPool ( T, Args ... ) : ThreadPool!(RunArgTypes!(T))
{
    /**************************************************************************
    
        Convenience This and OPool alias
    
     **************************************************************************/

    private alias typeof (this) This;
    
    private alias ObjectPool!(T, Args) OPool;
    
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
    
    public this ( Args args, size_t workers, size_t q_size = 0 )
    {
    	super(workers, q_size);
        
        this.pool = new OPool(args);
        
        this.pool.limit(workers);
    }
    
    
    /**************************************************************************
    
	    Destructor.
	    
	    Waits for all active threads in the pool to finish, then deletes the
	    object pool. (It's dangerous for this to happen the other way around!)
	
	**************************************************************************/

    ~this ( )
    {
    	debug Trace.formatln("{}.~this - waiting for {} threads to finish", typeof(this).stringof, super.activeJobs());
    	super.shutdown();
    	delete this.pool;
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
    	OPool.PoolItem item;
        synchronized ( this )
        {
        	item = this.pool.get();
        }
        
        try
        {
        	item.run(args);
        }
        catch ( Exception e )
        {
        	debug Trace.formatln(typeof(this).stringof ~ ".runItem - caught Exception '" ~ e.msg ~ "' which wasn't handled by "
        			~ T.stringof ~ " (maybe it should be?)");
        }
        catch ( Object e )
        {
        	debug Trace.formatln(typeof(this).stringof ~ ".runItem - caught Object which wasn't handled by "
        			~ T.stringof ~ " (maybe it should be?)");
        }
        
        synchronized ( this )
        {
        	this.pool.recycle(item);
        }
    }
    
    /**************************************************************************
    
        Factory method; creates a pool instance
        
        Params:
            args = default arguments to pass to constructor on pool item creation
    
        Returns:
            new pool instance
    
    **************************************************************************/
    
    public static This newPool ( Args args, size_t workers, size_t q_size = 0 )
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

/*******************************************************************************

	Unittests

*******************************************************************************/

debug ( OceanUnitTest )
{
	private import 	tango.core.Thread;
	private import 	tango.math.random.Random;
	private	import	tango.time.StopWatch;
	private	import  tango.core.Memory;
	
	const NUM_OBJECTS = 10;


    /***************************************************************************

		Object used by ObjectThreadPool.
		
		The run method randomly either throws an exception or sleeps for a very
		short time.
	
	 **************************************************************************/

	class MyObject
	{		
		protected static uint obj_count;
		protected static Random random;

		public static bool destroyed;

		public static this ( )
		{
			random = new Random();
		}

		protected synchronized static uint randomWait ( )
		{
			uint Usecs;
			MyObject.random(Usecs);
			Usecs %= 200;
			return Usecs;
		}
		
		protected uint obj_id;
		protected uint count;

		public this ( )
		{
			this.obj_id = obj_count++;
			Trace.formatln("Constructed object {}", this.obj_id);
			assert(this.obj_id < NUM_OBJECTS);
            this.destroyed = false;
		}
		
		public void run ( bool bad )
		{
            if(bad)
            {
                auto Usecs = MyObject.randomWait();
                if (Usecs == 0)
                {
                    throw new Exception("THIS IS SUPPOSED TO HAPPEN IN THIS UNITTEST");
                }
                else
                {
                    double secs = cast (double) Usecs / 1_000_000;
                    Thread.sleep(secs);
                }
            }
		}

		~this ( )
		{
			MyObject.destroyed = true;
		}
	}
    
    
    class Empty
    {   
        void delegate() r;
        this(void delegate() d)
        {
            r=d;
        }
        void run(int p,char[] o)
        {           
            r();
            if(p==10)
                throw new Exception("catch me if you can");
            else if(p==11)
                throw new Object();
        }
        ~this()
        {            
        }
    }
    
    
    
    
	unittest
	{
        Trace.formatln("ObjectThreadPool: Running general unittest");
        byte ran = 0;
        void setRun() {  ran += 1; }
        
        /***********************************************************************
         
            Tests finish, tryAssign, activeJobs, 
            throwing of assign and append when no workers are available
            
        ***********************************************************************/
        
        {   
            scope pool = new ObjectThreadPool!(Empty,void delegate())(&setRun,1);
            
            assert(pool.tryAssign(4,"hi"));            
            pool.finish();      
            
            assert(ran);  ran = 0;            
                       
            assert(pool.activeJobs == 0);   
            assert(pool.pool.getNumItems == 1);
                        
            bool catched = false;
            try pool.assign(3,"ho");
            catch (Exception e) catched = true;
            assert(catched);    catched = false;
                        
            pool.finish();
            
            try pool.append(5,"oh");
            catch (Exception e) catched = true;
            assert(catched);
        }       
        for(auto i=0;i<200;++i)
        {
            Trace.formatln("\nRunning iteration {}",i);
            ran = 0; 
            scope pool = ObjectThreadPool!(Empty,void delegate()).newPool(&setRun,1);
 
            pool.append(3,"iy");   
            pool.assign(2,"2");

            pool.wait();
            assert(ran == 2); ran = 0;
            
            // Test if Exceptions/Objects are being catched
            
            
            pool.assign(10,"throw");
                      
            pool.assign(11,"throw");
            
            pool.wait();
            
            assert(ran == 2); ran = 0;            
            
            
        }
        
        {
            Trace.formatln("Running ocean.core.ObjectThreadPool Exception safety test");
            StopWatch sw;
            scope opool = new ObjectThreadPool!(MyObject)(NUM_OBJECTS);
            /***********************************************************************

             Object non-destruction and thread pool limit test
             
             ***********************************************************************/
            const ITERATIONS = 100_000;
            uint count;
            do
            {
                opool.assign(true);
                assert (!MyObject.destroyed, "ObjectThreadPool unittest - MyObject destructor called during the main loop");
                assert (opool.activeJobs() <= NUM_OBJECTS, "ObjectThreadPool unittest - object thread pool has too many active threads!");
            }
            while (++count < ITERATIONS);
            for (uint i = 0; i < 5; i++)
            {
                count = 0;
                sw.start();
                do
                {
                    opool.assign(true);
                    assert (!MyObject.destroyed, "ObjectThreadPool unittest - MyObject destructor called during the main loop");
                    assert (opool.activeJobs() <= NUM_OBJECTS, "ObjectThreadPool unittest - object thread pool has too many active threads!");
                }
                while (++count < ITERATIONS);
                Trace.formatln(
                               "Iteration: {}\t ObjectPool assignes/s: {}\t Memory: {}",
                               i, count / sw.stop(), GC.stats["poolSize"]).flush();
            }
            Trace.formatln("done unittest\n");
        }
        {
            Trace.formatln("Running ocean.core.ObjectThreadPool performance test");
            StopWatch sw;
            scope opool = new ObjectThreadPool!(MyObject)(NUM_OBJECTS);
            
            /***********************************************************************

             Object non-destruction and thread pool limit test
             
             ***********************************************************************/
            const ITERATIONS = 100_000;
            uint count;
            do
            {
                opool.assign(false);
                assert (!MyObject.destroyed, "ObjectThreadPool unittest - MyObject destructor called during the main loop");
                assert (opool.activeJobs() <= NUM_OBJECTS, "ObjectThreadPool unittest - object thread pool has too many active threads!");
            }
            while (++count < ITERATIONS);
            
            for (uint i = 0; i < 5; i++)
            {
                count = 0;
                sw.start();
                do
                {
                    opool.assign(false);
                    assert (!MyObject.destroyed, "ObjectThreadPool unittest - MyObject destructor called during the main loop");
                    assert (opool.activeJobs() <= NUM_OBJECTS, "ObjectThreadPool unittest - object thread pool has too many active threads!");
                }
                while (++count < ITERATIONS);
                Trace.formatln(
                               "Iteration: {}\t ObjectPool assignes/s: {}\t Memory: {}",
                               i, count / sw.stop(), GC.stats["poolSize"]).flush();
            }
            Trace.formatln("done unittest\n");
        }
    }
    
}
