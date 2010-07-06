/*******************************************************************************

    I/O wait and retry callback manager 

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        November 2009: Initial release

    authors:        David Eckardt, Gavin Norman

    --

    Description:

    Provides a simple means for trying a block of code and retrying it if any
    exceptions are caught within.

    The class contains a built-in retry loop method, which is passed a delegate
    (usually a code block as an anonymous delegate) to be repeatedly retried on
    exception.

	A callback delegate can be set, which is called each time an exception is
	caught inside the retry loop. The default callback delegate (Retry.wait)
	simply waits a while.

	The default loop catches any exception (Exception). If finer grained control
	over exception handling is required, the class provides two possibilities:

    	1: Deriving a new class from Retry, and overriding the protected
    		defaultLoop method. Any exceptions can be handled in this way.

    	2: Passing a list of (one or more) exception handling delegates to the
    		loop method. Only exceptions from ocean.core.Exception and
    		tango.core.Exception can be handled in this way, as the loop method
    		uses a mixin to construct the try-catch blocks (and as the mixed-in
    		code is in the scope of *this* file, it can only reference classes
    		imported in *this* file).

	The first option is also more useful if you need to use the retry loop in
	multiple places throughout your code, rather than copying the exception
	handling delegates around.

    --
    
    General usage:
    
    ---
    
        import $(TITLE);

    	auto retry = new Retry(250, 10); // Retry up to 10 times, wait 250 ms
                                             // before each retry

		retry.loop({
			// do something which you want to retry
		});

    ---

	Exception handling delegates example:

    ---

        import $(TITLE);

    	auto retry = new Retry(250, 10); // Retry up to 10 times, wait 250 ms
                                             // before each retry

		retry.loop(
			{
				// do something which you want to retry
			},
			(SocketException e)
			{
				// exception handling code for type SocketException
			}
			(IOException e)
			{
				// exception handling code for type IOException
			}
		);

    ---

	Exception handling by overriding defaultLoop example:

    ---

        import $(TITLE);

		class SpecialException : Exception
		{
			// ...
		}

		class SpecialRetry : Retry
		{
			override protected void defaultLoop ( void delegate ( ) code_block )
		    {
				do try
				{
					super.tryBlock(code_block);
				}
				catch ( SpecialException e )
			    {
					// exception handling code for type IOException
					// for example:
			        super.handleException(e);
			    }
				while ( super.again )
			}
		}

    	auto retry = new SpecialRetry(250, 10); // Retry up to 10 times, wait 250 ms
                                                // before each retry

		retry.loop({
				// do something which you want to retry
		});

    ---
    
*******************************************************************************/

module ocean.io.Retry;



/*******************************************************************************

	Imports

*******************************************************************************/

private     import      Ctime  = tango.stdc.posix.time:      nanosleep;

private     import      Ctimer = tango.stdc.posix.timer:     timespec;

private     import               tango.stdc.time:            time_t;

private import ocean.core.Exception;

private import ocean.util.OceanException;

private import tango.core.Exception;

version = TRACE;

version ( TRACE )
{
	private import Integer = tango.text.convert.Integer;
    private import tango.util.log.Trace;
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
        function, returning void and acceptiong no arguments).
        Also convenience aliases for the templated struct, and the delegate and
        function types.
      
    ***************************************************************************/

	public alias DelgOrFunc!(void) Callback;
	public alias Callback.DelgType CallbackDelg;
	public alias Callback.FuncType CallbackFunc;

	public Callback callback;


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


    /***************************************************************************
    
    	Should the retry loop again? Used by the loop and handleException
    	methods.

    ***************************************************************************/

    public bool again;


    /**************************************************************************
    
        This alias for method chaining
    
     **************************************************************************/
    
    private alias typeof (this) This;

    
    /**************************************************************************
    
	    String buffer for outputting the count of retries to Trace
	
	 **************************************************************************/

    version ( TRACE )
    {
    	protected char[] retry_count;
    }


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
        
        If x is an exception, calls the retry callback method and rethrows x if
        the callback indicates no retrying.
        If x is a string, calls the retry callback method with this string.
        
        Params:
            x = exception or message string
        
        Returns:
            true to continue or false to cancel retrying.
        
    ***************************************************************************/
    
    public bool opCall ( T ) ( T x )
    {
        bool retry;
        
        static if (is (T : Exception))
        {
            retry = this.callback(x.msg);
            
            if (!retry) throw (x);
        }
        else static if (is (T == char[]))
        {
            retry = this.callback(x);
        }
        else static assert (false, This.stringof ~ ".opCall: "
                            "Exception and char[] supported, not " ~ T.stringof);
        
        return retry;
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
    
		Standard try / catch / retry loop. Can be called from classes which use
		this class.

		Can be optionally passed a template tuple consisting of exception
		handling delegates, in which case a try-catch block is constructed with
		a mixin template.
		
		In the case where no exception handlers are passed, the defaultLoop
		method is called instead. (defautlLoop is a separate method so it can be
		conveniently overridden if needes.)

		Template params:
			H = tuple of exception handling delegates

	    Params:
	        code_block = code to try
	        handlers = tuple of exception handling delegates

	***************************************************************************/

    public void loop ( H ... ) ( void delegate ( ) code_block, H handlers )
    {
		this.resetCounter();

    	// End-user specified exception handling
    	static if ( H.length )
    	{
    	    do mixin (TryCatchCode!("code_block", "handlers", H));
    	    while ( this.again )
    	}
    	// Default exception handling
    	else
    	{
    		this.defaultLoop(code_block);
    	}
    }


    /***************************************************************************
    
		Runs a block of code. Called within a try block inside a retry loop.
		This method exists so that defaultLoop (below) can be as simplfied as
		possible, making it easy to override.

	***************************************************************************/

    public void tryBlock ( void delegate ( ) code_block )
    {
    	this.again = false;
    	code_block();
    }


    /***************************************************************************
    
		Standard try / catch / retry loop. Can be overridden by classes derived
		from Retry.
	
		Calls the passed code block, catches any exceptions, and retries
		the delegate according to the retry setup.
	
	    Params:
	        code_block = code to try
	
	***************************************************************************/

    protected void defaultLoop ( void delegate ( ) code_block )
    {
		do try
		{
			this.tryBlock(code_block);
		}
		catch ( Exception e )
	    {
	        this.handleException(e);
	    }
		while ( this.again )
	}


	/***************************************************************************
    
		Retry loop exception handler. Decides whether to try the loop again, and
		if so calls the loop callback delegate. If not trying again, then the
		caught exception is rethrown.
		
		Template params:
			E = exception type, defaults to Exception. If the exception is
			rethrown, it is thrown as this type.
			
	    Params:
	        e = exception receieved

	***************************************************************************/

    public void handleException ( E : Exception = Exception ) ( Exception e, char[] e_type = "Exception" )
	{
    	version ( TRACE )
    	{
    		this.retry_count.length = 10; // uint.max fits in 10 characters
    		this.retry_count = Integer.format(this.retry_count, this.n);
        	Trace.formatln("\nRetry " ~ this.retry_count ~ ": " ~ E.stringof ~ ": " ~ e.msg);
    	}

    	// Is retry enabled and are we below the retry limit or unlimited?
    	this.again = this.enabled && ((this.n < this.retries) || !this.retries);

        if (this.again)
        {
            this.n++;

            this.callback();
        }
        else
        {
	    	version ( TRACE ) Trace.formatln("Decided not to try again");

	    	static if ( is ( E == Exception ) )
	    	{
	    		throw e;
	    	}
	    	else
	    	{
	    		throw new E(e.msg);
	    	}
	    }
	}


    /***************************************************************************

	    Default retry callback method for retries. Just sleeps a while.
	
	    Params:
	        message = error message
	
	***************************************************************************/
	
	public void wait ( )
	{
		this.sleep(this.ms);
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
	
	public static void sleep ( time_t ms )
	{
	    auto ts = Ctimer.timespec(ms / 1_000, (ms % 1_000) * 1_000_000);
	    
	    while (Ctime.nanosleep(&ts, &ts)) {}
	}


    /***************************************************************************
    
		Try catch mixin template. Creates the code for a try-catch block for a
		retyr loop, trying the provided code block, and catching the specified
		exception types.
		
	    Template params:
	    	code_block = code to try
	    	handlers = the name of a tuple of exception handlers
	    	H = tuple of types of exception handlers
	
	***************************************************************************/

	protected template TryCatchCode ( char[] code_block, char[] handlers, H ... )
	{
	    static if (H.length)
	    {
	        static if (is (H[$ - 1] Fn == delegate))
	        {
	            static if (is (Fn Args == function))
	            {
	                static assert (Args.length == 1, "Exception handler must take exactly one argument");
	                static assert (is (Args[0] : Exception), "Exception handler must take 'Exception', not '" ~ Args[0].stringof ~ '\'');
	                
	                const TryCatchCode = TryCatchCode!(code_block, handlers, H[0 .. $ - 1]) ~
	                                                   "catch (" ~ Args[0].stringof ~ " e) "
	                                                   "{" ~
	                                                       handlers ~ "[" ~ (H.length - 1).stringof ~ "](e);"
	                                                   "}\n";
	            }
	        }
	        else static assert (false, "'void delegate(Exception)' required, not '" ~ H.stringof ~ '\'');
	    }
	    else
	    {
	        const TryCatchCode = "try { this.tryBlock(" ~ code_block ~ "); }\n";
	    }
	}
}



/*******************************************************************************

	Unittest

********************************************************************************/

debug ( OceanUnitTest )
{
	private import tango.util.log.Trace;


    class SpecialException : Exception
    {
    	public this ( char[] _msg )
    	{
    		super(_msg);
    	}
    }


    class SpecialRetry : Retry
    {
    	override protected void defaultLoop ( void delegate ( ) code_block )
    	{
    		do try
    		{
    			this.tryBlock(code_block);
    		}
    		catch ( SpecialException e )
    	    {
    	        this.handleException(e);
    	    }
    		while ( this.again )
    	}
    }


    unittest
    {
        Trace.formatln("Running ocean.io.Retry unittest");

        const char[] fail_msg = "FAIL";
        
        const uint retry_times = 3;

        uint count;

        auto retry = new Retry;
        retry.retries = retry_times;
        retry.ms = 10;

        auto special_retry = new SpecialRetry;
        special_retry.retries = retry_times;
        special_retry.ms = 10;


        /***********************************************************************
        
        	Loop test
        
        ***********************************************************************/

        Trace.formatln("\nTesting retry loop...");

        count = 0;
        try
        {
	        retry.loop({
	        	count++;
	        	throw new Exception(fail_msg);
	        });
        }
        catch ( Exception e )
        {
        	assert(e.msg == fail_msg, "Unexpected exception: " ~ e.msg);
        }

        assert(count == retry_times + 1, "Retry loop not executed the right number of times");


        /***********************************************************************
        
    		Loop exception handling test
    
        ***********************************************************************/

        Trace.formatln("\nTesting retry loop with custom exception handling...");

        count = 0;
        try
        {
	        retry.loop(
        		{
		        	count++;
		        	throw new IOException(fail_msg);
		        },
		        (IOException e)
		        {
		        	retry.handleException(e);
		        }
	        );
        }
        catch ( IOException e )
        {
        	assert(e.msg == fail_msg, "Unexpected exception: " ~ e.msg);
        }
        catch ( Exception e )
        {
        	assert(false, "loop didn't work - should have caught an IOException, actually caught an Exception");
        }

        assert(count == retry_times + 1, "Retry loop not executed the right number of times");


        /***********************************************************************

			Custom loop test

	    ***********************************************************************/

	    Trace.formatln("\nTesting retry loop with custom loop...");

	    count = 0;
	    try
	    {
	    	special_retry.loop({
		        	count++;
		        	throw new SpecialException(fail_msg);
			});
	    }
	    catch ( SpecialException e )
	    {
	    	assert(e.msg == fail_msg, "Unexpected exception: " ~ e.msg);
	    }
	    catch ( Exception e )
	    {
	    	assert(false, "loop didn't work - should have caught a SpecialException, actually caught an Exception");
	    }
	
	    assert(count == retry_times + 1, "Retry loop not executed the right number of times");

        Trace.formatln("\nDone unittest\n");
    }
}

