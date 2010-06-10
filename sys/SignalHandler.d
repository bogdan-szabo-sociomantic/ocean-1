/*******************************************************************************

    Simple C/Posix Signals manager

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        Febrruary 2010: Initial release
    
    authors:        David Eckardt, Gavin Norman
    
    --
    
    Description:
    
    Register signal handlers for C/Posix Signals and, as an option, reset to
    default signal handlers.
    
    The module also contains a class (TerminationSignal) for conveniently
    assigning an arbitrary number of program-exit handlers. This class sets up a
    handler for the SIGINT and SIGTERM signals, which are passed when a program
    is interrupted with Ctrl-C. When the terminate signal handler is called, it
    in turn calls all functions / delegates which were registered with it. This
    class can be used to conveniently ensure that another class / struct
    performs its required shutdown behaviour, even when the program is
    interrupted.

	TerminationSignal usage example:

	---

	private import ocean.sys.SignalHandler;

	class MyClass
	{
		public this ( )
		{
			TerminationSignal.handle(&this.terminate);
		}
		
		public void terminate ( int code )
		{
			// required shutdown behaviour for this class
		}
	}

    ---
    
*******************************************************************************/
    
module ocean.sys.SignalHandler;



/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import tango.stdc.signal: signal, raise, SIGABRT, SIGFPE,  SIGILL,
                                          SIGINT,  SIGSEGV, SIGTERM, SIG_DFL;

version (Posix) private import tango.stdc.posix.signal: SIGALRM, SIGBUS,  SIGCHLD,
                                                        SIGCONT, SIGHUP,  SIGKILL,
                                                        SIGPIPE, SIGQUIT, SIGSTOP,
                                                        SIGTSTP, SIGTTIN, SIGTTOU,
                                                        SIGUSR1, SIGUSR2, SIGURG;

debug
{
	private import tango.util.log.Trace;
}



struct SignalHandler
{
    static:

    /**************************************************************************
    
        Signal handler type alias definition
     
     **************************************************************************/

    extern (C) alias void function ( int code ) SignalHandler;


    /**************************************************************************
    
        Signal enumerator and identifier strings
     
     **************************************************************************/

    version (Posix)
    {
        enum : int
        {
            SIGABRT   = .SIGABRT, // Abnormal termination
            SIGFPE    = .SIGFPE,  // Floating-point error
            SIGILL    = .SIGILL,  // Illegal hardware instruction
            SIGINT    = .SIGINT,  // Terminal interrupt character
            SIGSEGV   = .SIGSEGV, // Invalid memory reference
            SIGTERM   = .SIGTERM, // Termination
            
            SIGALRM   = .SIGALRM,
            SIGBUS    = .SIGBUS,
            SIGCHLD   = .SIGCHLD,
            SIGCONT   = .SIGCONT,
            SIGHUP    = .SIGHUP,
            SIGKILL   = .SIGKILL,
            SIGPIPE   = .SIGPIPE,
            SIGQUIT   = .SIGQUIT,
            SIGSTOP   = .SIGSTOP,
            SIGTSTP   = .SIGTSTP,
            SIGTTIN   = .SIGTTIN,
            SIGTTOU   = .SIGTTOU,
            SIGUSR1   = .SIGUSR1,
            SIGUSR2   = .SIGUSR2,
            SIGURG    = .SIGURG
        }
        
        const char[][] Ids =
        [
            0         : "",
            SIGABRT   : "SIGABRT",
            SIGFPE    : "SIGFPE",
            SIGILL    : "SIGILL",
            SIGINT    : "SIGINT",
            SIGSEGV   : "SIGSEGV",
            SIGTERM   : "SIGTERM",
             
            SIGALRM   : "SIGALRM",
            SIGBUS    : "SIGBUS",
            SIGCHLD   : "SIGCHLD",
            SIGCONT   : "SIGCONT",
            SIGHUP    : "SIGHUP",
            SIGKILL   : "SIGKILL",
            SIGPIPE   : "SIGPIPE",
            SIGQUIT   : "SIGQUIT",
            SIGSTOP   : "SIGSTOP",
            SIGTSTP   : "SIGTSTP",
            SIGTTIN   : "SIGTTIN",
            SIGTTOU   : "SIGTTOU",
            SIGUSR1   : "SIGUSR1",
            SIGUSR2   : "SIGUSR2",
            SIGURG    : "SIGURG"
        ];
    }
    else
    {
        enum : int
        {
            SIGABRT   = .SIGABRT, // Abnormal termination
            SIGFPE    = .SIGFPE,  // Floating-point error
            SIGILL    = .SIGILL,  // Illegal hardware instruction
            SIGINT    = .SIGINT,  // Terminal interrupt character
            SIGSEGV   = .SIGSEGV, // Invalid memory reference
            SIGTERM   = .SIGTERM  // Termination
        }
        
        const char[][] Ids =
        [
             0         : "",
             SIGABRT   : "SIGABRT",
             SIGFPE    : "SIGFPE",
             SIGILL    : "SIGILL",
             SIGINT    : "SIGINT",
             SIGSEGV   : "SIGSEGV",
             SIGTERM   : "SIGTERM"
         ];
    }
    
    
    
    /**************************************************************************
    
        Default handlers registry to memorize the default handlers for reset
     
     **************************************************************************/

    synchronized private SignalHandler[int] default_handlers;
    
    /**************************************************************************
    
        Sets/registers handler for signal code.
        
        Params:
            code    = code of signal to handle by handler
            handler = signal handler callback function
     
     **************************************************************************/
    
    void set ( int code, SignalHandler handler )
    {
        set([code], handler);
    }
    
    /**************************************************************************
    
        Sets/registers handler for signals of codes.
        
        Params:
            codes   = codes of signals to handle by handler
            handler = signal handler callback function
     
     **************************************************************************/

   void set ( int[] codes, SignalHandler handler )
    {
        synchronized foreach (code; codes)
        {
            SignalHandler prev_handler = signal(code, handler);
            
            if (!(code in this.default_handlers))
            {
                this.default_handlers[code] = prev_handler;
            }
        }
    }
    
   /**************************************************************************
   
       Resets handlers for signal codes to the default handler and unregisters
       the handler.
       
       Params:
           code = signal code
    
    **************************************************************************/
   
   void reset ( int code )
   {
       reset([code]);
   }
   
   /**************************************************************************
   
       Resets handlers for signals of codes to the default handlers and
       unregisters the handlers.
       
       Params:
           codes = signal codes
    
    **************************************************************************/

    void reset ( int[] codes )
    {
        synchronized foreach (code; codes)
        {
            SignalHandler* handler = code in this.default_handlers;
            
            if (handler)
            {
                signal(code, *handler);
                
                this.default_handlers.remove(code);
            }
        }
    }
    
	/**************************************************************************
    
        Returns the codes for which signal handlers are registered.
        
        Returns:
            list of codes
     
     **************************************************************************/

    int[] registered ( )
    {
        return this.default_handlers.keys.dup;
    }
    
    /**************************************************************************
    
        Returns the identifier string for signal code.
        
        Returns:
            identifier string for signal code
     
     **************************************************************************/

    char[] getId ( int code )
    {
        assert ((this.Ids.length > code) && (code >= 0), "invalid signal code");
        
        return this.Ids[code];
    }
}



/*******************************************************************************

	Class for convenient program termination handling

*******************************************************************************/

class TerminationSignal
{
	/***************************************************************************

		Aliases for delegate and function termination handlers
	
	***************************************************************************/

	public alias void delegate ( int ) DgHandler;
	public alias void function ( int ) FnHandler;


	/***************************************************************************

		Lists of delegate and function termination handlers. Each will be called
		on the receipt of a SIGINT or SIGTERM.

	***************************************************************************/

	protected static DgHandler[] delegates;
	protected static FnHandler[] functions;


	/***************************************************************************
	
	    Adds a delegate to the list of terminate handlers.
	    
	    Params:
	    	dg = delegate to call on termination
	
	***************************************************************************/

	public static void handle ( DgHandler dg )
	{
		delegates ~= dg;
		activate();
	}


	/***************************************************************************
	
	    Adds a function to the list of terminate handlers.
	    
	    Params:
	    	fn = function to call on termination
	
	***************************************************************************/

	public static void handle ( FnHandler fn )
	{
		functions ~= fn;
		activate();
	}


	/***************************************************************************
	
	    Redirects the terminate signal (Ctrl-C) to the terminate method below.
	
	***************************************************************************/

	public static void activate ( )
	{
		SignalHandler.set([SIGTERM, SIGINT], &terminate);
	}


	/***************************************************************************
	
	    Sets terminate signal handling back to the default (ie not handled by
	    this class).
	
	***************************************************************************/

	public static void deactivate ( )
	{
		SignalHandler.reset([SIGTERM, SIGINT]);
	}


	/***************************************************************************

		Termination handler. Receives a signal, calls all registered function &
		delegate termination handlers, then passes the signal on to the default
		handler.

	    Params:
	        code = signal code

	***************************************************************************/

	extern (C) protected static synchronized void terminate ( int code )
	{
		debug Trace.formatln(SignalHandler.getId(code) ~ " raised: terminating");

		// Process delegates
		foreach ( dg; delegates )
		{
			dg(code);
		}

		// Process functions
		foreach ( fn; functions )
		{
			fn(code);
		}

		// Deactivate this signal handler and pass this signal on to the default
		// handler
		deactivate();
		raise(code);
	}
}

