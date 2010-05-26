/******************************************************************************

    I/O wait and retry callback manager 
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    version:        November 2009: Initial release
    
    authors:        David Eckardt
    
    --
    
    Description:
    
    Provides a callback method suitable for a wait and retry loop for I/O
    operations. This callback method can be invoked if an I/O operation fails;
    when invoked, it waits for a certain period of time, increments a counter
    and tells by return value whether the counter has reached a certain level.
    
    As an option, a custom retry callback method (delegate or function
    reference) may be supplied.
    
    Also optionally, a custom timeout method may be supplied, which is called by
    the built-in wait method after the specified number of retries has passed.
    
    --
    
    Usage:
    
    ---
    
        import $(TITLE);
        
        Retry retry = new Retry(250, 10); // Retry up to 10 times, wait 250 ms
                                          // before each retry
        
        bool more;
        
        retry.resetCounter();
        
        do
        {
            try
            {
                more  = false;
                
                doSomeIoOperationWhichMayFail();
            }
            catch (Exception e)
            {
                more = retry(e);    // Retry up to 10 times, then rethrows e
            }
        }
        while (more)
        
    ---

    For cases where you don't need to specifically handle different exception
    types, the Retry class includes a standard loop, which is passed a 
    block of code (usually an anonymous delegate) for the action to repeatedly
    try / retry.
    
    Example:
    
    ---

        import $(TITLE);

        class C
        {
        	Retry retry;

			this ( )
			{
	        	this.retry = new Retry(250, 10); // Retry up to 10 times, wait 250 ms
	                                             // before each retry
			}

			void doSomething ( int arg )
			{
				this.retry.loop({
					// do something with arg
				});
			}
		}

    ---
    
 ******************************************************************************/

module ocean.io.Retry;



/*******************************************************************************

	Imports

*******************************************************************************/

private     import      Ctime  = tango.stdc.posix.time:      nanosleep;

private     import      Ctimer = tango.stdc.posix.timer:     timespec;

private     import               tango.stdc.time:            time_t;

debug
{
    private     import 			     tango.util.log.Trace;
}


/*******************************************************************************

	Template struct encapsulating a pointer to either a delegate or a
	function.
	
	Template parameters:
		R = the return type of the function / delegate
		T = tuple of the function / delegate's parameters

*******************************************************************************/

struct DelgOrFunc ( R, T ... )
{
	/***************************************************************************
	
	    Convenience aliases for the templated delegate & function types.
	
	***************************************************************************/
	
	alias R delegate ( T ) DelgType;
	alias R function ( T ) FuncType;
	
	
	/***************************************************************************
	
	    Union of the templated delegate & function types.
	    Also has a void* member, used for convenient comparison with null.
	
	***************************************************************************/
	
	union Pointer
	{
		DelgType delg;
		FuncType func;
		void* address;
	}


	/***************************************************************************
	
	    The delegate / function pointer.
	
	***************************************************************************/
	
	Pointer pointer;
	
	
	/***************************************************************************
	
	    Flag denoting whether the pointer is to a delegate or a function.
	
	***************************************************************************/
	
	bool is_delegate;
	
	
	/***************************************************************************
	
	    Overloaded opAssign. Sets the pointer to a delegate with the
	    templated return type and arguments.
	    
	    Params:
	    	delg = delegate to set
	    
	    Returns:
	    	void
	
	***************************************************************************/
	
	public void opAssign ( DelgType delg )
	{
	    this.pointer.delg = delg;
	    this.is_delegate = true;
	}
	
	
	/***************************************************************************
	
	    Overloaded opAssign. Sets the pointer to a function with the
	    templated return type and arguments.
	    
	    Params:
	    	func = function to set
	    
	    Returns:
	    	void
	
	***************************************************************************/
	
	public void opAssign ( FuncType func)
	{
	    this.pointer.func = func;
	    this.is_delegate = false;
	}
	
	
	/***************************************************************************
	
		Checks whether the delegate / function pointer has been set.
	
	    Params:
	    	void
	    
	    Returns:
	    	bool
	
	***************************************************************************/
	
	public bool isNull ( )
	{
		return this.pointer.address == null;
	}
	
	
	/***************************************************************************
	
	    Overloaded opCall.
	    Asserts if no function / delegate has been set.
	    Otherwise calls the function / delegate with the passed arguments.
	    
	    Params:
	    	t = templated tuple of arguments to pass to the function /
	    	delegate.
	    
	    Returns:
	    	templated function / delegate return type
	
	***************************************************************************/
	
	public R opCall ( T t )
	{
		assert ( !this.isNull() );
		return this.is_delegate ? this.pointer.delg(t) :
	        this.pointer.func(t);
	}
}



/*******************************************************************************

	Retry class

*******************************************************************************/

class Retry
{
    /***************************************************************************
    
        Callback struct. Holds the callback method reference (either delegate or
        function, returning bool and acceptiong a char[]).
        Also convenience aliases for the templated struct, and the delegate and
        function types.
      
    ***************************************************************************/

	public alias DelgOrFunc!(bool, char[]) Callback;
	public alias Callback.DelgType CallbackDelg;
	public alias Callback.FuncType CallbackFunc;

	public Callback callback;


	/***************************************************************************
    
	    Timeout struct. Holds the timeout method reference (either delegate or
	    function, returning void and accepting no arguments).
	    Also convenience aliases for the templated struct, and the delegate and
	    function types.
	  
	***************************************************************************/

	public alias DelgOrFunc!(void) Timeout;
	public alias Timeout.DelgType TimeoutDelg;
	public alias Timeout.FuncType TimeoutFunc;

	public Timeout timeout;


	/***************************************************************************
    
        Parameters for default wait/retry callback method; may be changed at any
        time
        
        These are effective if the default wait/retry callback method is used.
        
        enabled = do retry
        ms      = time to wait before each retry
        retries = maximum number of consecutive retries; 0 = unlimited
        n       = internal counter of the number of retries
        
    ***************************************************************************/
    
    public bool enabled = true;
    public uint ms      = 500;
    public uint retries = 0;
    
    private uint n = 0;


    /**************************************************************************
    
        This alias for method chaining
    
     **************************************************************************/
    
    private alias typeof (this) This;


    /**************************************************************************
    
        Constructor
           
    **************************************************************************/
    
    public this ( )
    {
        this.setDefaultCallback();
    }


    /**************************************************************************
    
        Constructor
       
        Params:
            ms = default retry callback: time to wait before each retry (ms)
            retries  = default retry callback: maximum number of retries
       
    **************************************************************************/
    
    public this ( uint ms, uint retries )
    {
        this();
        this.ms = ms;
        this.retries = retries;
    }
    
    
    /**************************************************************************
    
        Constructor
       
        Params:
            delg = callback method
       
     **************************************************************************/
    
    public this ( CallbackDelg delg )
    {
        this();
        
        this = delg;
    }
    
    
    /**************************************************************
    
        Constructor
       
        Params:
            func = callback method
    
     ***************************************************************/
    
    public this ( CallbackFunc func )
    {
        this();
        
        this = func;
    }


    /**************************************************************************
        
        Calls the retry callback method.
        
        Params:
            message = message regarding failed request
             
        Returns:
            true to continue retrying or false to abort
    
     **************************************************************************/
    
    public bool opCall ( char[] message )
    {
    	return this.callback(message);
    }


    /**************************************************************************
        
        Calls the retry callback method and rethrows e if the callback indicates
        no retrying.
        
        Params:
            e = exception caught on previously failed operation
    
    ****************************************************************/
    
    public void opCall ( Exception e )
    {
        bool retry = this.callback(e.msg);
        if (!retry) throw (e);
    }


    /**************************************************************************
     
       Resets the retry callback to the default wait method.
       
       Returns:
            this instance
            
    ****************************************************************/
    
    public This setDefaultCallback ( )
    {
        this.opAssign(&this.wait);
        return this;
    }


    /**************************************************************************
     
         Resets the wait parameters.
     
        Returns:
            this instance
            
     **************************************************************************/
    
    public This setDefaultParams ( )
    {
        this.enabled = this.enabled.init;
        this.ms      = this.ms.init;
        this.retries = this.retries.init;
        
        return this;
    }


    /**************************************************************************
     
       Sets the callback method.
       
       Params:
            delg = callback method delegate
            
       Returns:
            this instance
            
     **************************************************************************/
    
    public This opAssign ( CallbackDelg delg )
    {
    	this.callback = delg;
        return this;
    }


    /**************************************************************************
    
        Sets the callback method.
        
        Params:
             func = callback method function reference
             
        Returns:
             this instance
             
    ***************************************************************************/
    
    public This opAssign ( CallbackFunc func )
    {
    	this.callback = func;
        return this;
    }

    
    /**************************************************************************
    
        Resets the counter
                
        Returns:
            this instance
                  
     **************************************************************************/
    
    public This resetCounter ( )
    {
        this.n = this.n.init;
        
        return this;
    }


    /**************************************************************************
    
        Returns the counter level
                
        Returns:
            the counter level
                  
     **************************************************************************/
    
    public uint getCounter ( )
    {
        return this.n;
    }


    /***************************************************************************

        Default retry callback method for push/pop retries

        Params:
            message = error message

        Returns:
            true if the caller shall continue trying or false if the caller
            shall quit

    ***************************************************************************/

    public bool wait ( char[] message )
    {
    	this.debugTrace("Retry {} ({})", this.n, message);
    	
    	// Is retry enabled and are we below the retry limit or unlimited?
        bool retry = this.enabled && ((this.n < this.retries) || !this.retries);

        if (retry)
        {
            this.n++;
            
            this.sleep(this.ms);
        }
        else
        {
        	this.callTimeout();
        }

        if ( !retry )
        {
        	this.debugTrace("Decided not to try again");
        }

        return retry;
    }


    /***************************************************************************
    
	    Calls the custom timeout delegate / function (if set), and resets the
	    internal counter.

	    Params:
	        void

	    Returns:
	        void

	***************************************************************************/

    protected void callTimeout ( )
    {
    	if ( !this.timeout.isNull() )
    	{
       		this.debugTrace("Calling timeout function");
            
        	this.resetCounter();
       		this.timeout();
    	}
    }


    /***************************************************************************
    
	    Outputs a message to Trace if debug compiler switch is enabled.
	
	    Params:
	        as Trace.formatln
	
	    Returns:
	        void

		Note: doing this as a template function isn't ideal, it'd be nicer to be
		able to simply pass through the variadic args required for the format
		function. Unfortunately there's no syntax for this in D, and the other
		alternative of passing the variadic args to a method of type:
			void formatln(char[] fmt, va_list args, TypeInfo[] arg_types)
		in Trace isn't possible (as it doesn't expose such a method, and it's
		impossible to extend Trace due to everything in it being declared as
		final - thanks Tango! ;)

	***************************************************************************/

    protected void debugTrace ( T ... ) ( T t )
    {
    	debug
    	{
    		Trace.formatln(t);
    	}
    }


    /***************************************************************************
    
        Sleep in a multi-thread compatible way.
        sleep() in multiple threads is not trivial because when several threads
        simultaneously sleep and the first wakes up, the others will instantly
        wake up, too. See nanosleep() man page
        
        http://www.kernel.org/doc/man-pages/online/pages/man2/nanosleep.2.html
        
        or
        
        http://www.opengroup.org/onlinepubs/007908799/xsh/nanosleep.html
        
        Params:
            ms = milliseconds to sleep
    
    ***************************************************************************/

    static void sleep ( time_t ms )
    {
        auto ts = Ctimer.timespec(ms / 1_000, (ms % 1_000) * 1_000_000);
        
        while (Ctime.nanosleep(&ts, &ts)) {}
    }


    /***************************************************************************
    
		Standard try / catch / retry loop. Can be called from classes which use
		this class.

		Calls the passed code block, catches any exceptions, and retries
		the delegate according to the retry setup.

		Note: If your class needs to explcitly handle any exceptions of other
		types, it will need to implement its own version of this loop, adding
		extra catch blocks.
		
	    Params:
	        code_block = code to try

	***************************************************************************/

    public void loop ( void delegate () code_block )
    {
    	bool again;
    	this.resetCounter();

    	do try
        {
    		again = false;
        	code_block();
        }
        catch (Exception e)
        {
        	debug Trace.formatln("caught {} {}", typeof(e).stringof, e.msg);
            this.handleException(e, again);
        }
        while (again)
    }


    /***************************************************************************
    
		try / catch / retry loop which creates and throws exceptions of a new
		class on failure. Can be called from classes which use this class.
	
		Calls the passed code block, catches any exceptions, and retries
		the delegate according to the retry setup.
	
		Note: If your class needs to explcitly handle any exceptions of other
		types, it will need to implement its own version of this loop, adding
		extra catch blocks.

		Template params:
			E = type of exceptions to rethrow on failure

	    Params:
	        code_block = code to try
	
	***************************************************************************/

    public void loopRethrow ( E : Exception ) ( void delegate () code_block )
    {
    	bool again;
    	this.resetCounter();

    	do try
        {
        	again = false;
        	code_block();
        }
        catch (Exception e)
        {
        	debug Trace.formatln("caught {} {}", typeof(e).stringof, e.msg);
            this.handleException!(E)(e, again);
        }
        while (again)
    }


    /***************************************************************************
    
		Retry loop exception handler. Rethrows the exception if the retry
		callback says to not try again.
		
		Template params:
			E = exception type to rethrow. Defaults to Exception (in which case
				the exception passed is simply rethrown). If E is set to another
				exception type, then a new exception is thrown.
			
	    Params:
	        e = exception receieved
	        again = whether to try again or not
	
	***************************************************************************/
	
	protected void handleException ( E : Exception = Exception ) ( Exception e, ref bool again )
	{
		again = this.callback(e.msg); 
	    if ( !again )
	    {
	    	static if ( is(E == Exception) )
	    	{
	    		throw e;
	    	}
	    	else
	    	{
	    		throw new E(e.msg);
	    	}
	    }
	}

}

