/*******************************************************************************

    Simple C/Posix Signals manager

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        Febrruary 2010: Initial release
    
    authors:        David Eckardt, Gavin Norman, Mathias Baumann
    
    --
    
    Description:
    
    Register signal handlers for C/Posix Signals and, as an option, reset to
    default signal handlers. When a signal is received, all signal handlers
    which have been registered for that signal are called in series, optionally
    followed by the default handler. (The default handler is called if none of
    the user-registered signal handler functions / delegates returned false.)

    On unix, the constant SignalHandler.AppTermination provides a convenient
    warpper for the SIGINT and SIGTERM signals. This can be used to conveniently
    ensure that another class / struct performs its required shutdown behaviour,
    even when the program is interrupted.

	SignalHandler usage example:

	---

	private import ocean.sys.SignalHandler;

	class MyClass
	{
		public this ( )
		{
			SignalHandler.register(SignalHandler.SIGALRM, &this.alarm);
            SignalHandler.register(SignalHandler.AppTermination, &this.terminate);
		}
		
		public bool alarm ( int code )
		{
			// required alarm behaviour for this class

            return false; // don't call default handler
		}

	    public bool terminate ( int code )
        {
            // required shutdown behaviour for this class

            return true; // call default handler (terminates program)
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

private import ocean.core.UniStruct,
               ocean.core.StringEnum;

version (Posix) private import tango.stdc.posix.signal: SIGALRM, SIGBUS,  SIGCHLD,
                                                        SIGCONT, SIGHUP,  SIGKILL,
                                                        SIGPIPE, SIGQUIT, SIGSTOP,
                                                        SIGTSTP, SIGTTIN, SIGTTOU,
                                                        SIGUSR1, SIGUSR2, SIGURG;

debug
{
	private import tango.util.log.Trace;
}



class SignalHandler
{
    public alias bool delegate ( int ) DgHandler;
    public alias bool function ( int ) FnHandler;
    
    
    static:

    /**************************************************************************
    
        Signal handler type alias definition
     
     **************************************************************************/

    extern (C) alias void function ( int code ) SignalHandler;


    /**************************************************************************
    
        Signal enumerator and identifier strings
     
     **************************************************************************/

    alias StringEnumValue!(int) Sig;

    version (Posix)
    {
        StringEnum!(
                    Sig("SIGABRT", .SIGABRT), // Abnormal termination
                    Sig("SIGFPE ", .SIGFPE),  // Floating-point error
                    Sig("SIGILL ", .SIGILL),  // Illegal hardware instruction
                    Sig("SIGINT ", .SIGINT),  // Terminal interrupt character
                    Sig("SIGSEGV", .SIGSEGV), // Invalid memory reference
                    Sig("SIGTERM", .SIGTERM), // Termination
                    
                    Sig("SIGALRM", .SIGALRM),
                    Sig("SIGBUS ", .SIGBUS),
                    Sig("SIGCHLD", .SIGCHLD),
                    Sig("SIGCONT", .SIGCONT),
                    Sig("SIGHUP ", .SIGHUP),
                    Sig("SIGKILL", .SIGKILL),
                    Sig("SIGPIPE", .SIGPIPE),
                    Sig("SIGQUIT", .SIGQUIT),
                    Sig("SIGSTOP", .SIGSTOP),
                    Sig("SIGTSTP", .SIGTSTP),
                    Sig("SIGTTIN", .SIGTTIN),
                    Sig("SIGTTOU", .SIGTTOU),
                    Sig("SIGUSR1", .SIGUSR1),
                    Sig("SIGUSR2", .SIGUSR2),
                    Sig("SIGURG ", .SIGURG)
                ) Signals;
    }
    else
    {
        StringEnum!(
                    Sig("SIGABRT", .SIGABRT), // Abnormal termination
                    Sig("SIGFPE ", .SIGFPE),  // Floating-point error
                    Sig("SIGILL ", .SIGILL),  // Illegal hardware instruction
                    Sig("SIGINT ", .SIGINT),  // Terminal interrupt character
                    Sig("SIGSEGV", .SIGSEGV), // Invalid memory reference
                    Sig("SIGTERM", .SIGTERM) // Termination
                ) Signals;
    }
    
    /***************************************************************************
    
        Commonly used command line application termination signals
        
    ***************************************************************************/

    const int[] AppTermination = [SIGINT, SIGTERM];

    /***************************************************************************
    
        Alias for a general handler (can be either, delegate or function)
        
    ***************************************************************************/
    
    alias UniStruct!(DgHandler,FnHandler) Handler;
        
    /**************************************************************************
    
        Default handlers registry to memorize the default handlers for reset
     
     **************************************************************************/

    synchronized private SignalHandler[int] default_handlers;
    
    /***************************************************************************
    
        Lists of delegate and function signal handlers. Each will be called
        on the receipt of the previously registered signal
    
    ***************************************************************************/
    
    protected static  Handler[][int] handlers;
    
    /***************************************************************************
    
        registers handler for a signal code.
        
        The handler should return false if it wants to prevent 
        the invocation of the default handler.
        
        Does nothing if the handler was already registered for that
        signal code
        
        Params:
            code    = code of signal to handle by handler
            handler = signal handler callback function
     
    ***************************************************************************/
    
    void register ( T ) ( int code, T handler )
    {
        register([code], handler);
    }
    
    /**************************************************************************
    
        registers handler for signals of codes.
        
        The handler should return false if it wants to prevent 
        the invocation of the default handler.
        
        Does nothing if the handler was already registered for that
        signal code
         
        Params:
            codes   = codes of signals to handle by handler
            handler = signal handler callback function
     
     **************************************************************************/

   	void register ( T ) ( int[] codes, T handler )
   	{
       static if(!is( T == DgHandler ) && !is( T == FnHandler))
       {
           static assert(false,"register template only usable for DgHandler or FnHandler!");
       }
       
       synchronized foreach (code; codes)
       {   
           if (!(code in this.default_handlers))
           {
               this.default_handlers[code] = signal(code, &this.sighandler);
           }
           
           if (auto arrayOfhandlers = code in handlers)
           {
               foreach (arHandler ; *arrayOfhandlers)
               {
                   bool equal = arHandler.visit((FnHandler fn)
                   {
                       static if(is(T==FnHandler))
                       {
                           return (fn == handler);
                       }
                       else
                       {
                           return false;
                       }
                   },
                   (DgHandler dg)
                   {
                       static if(is(T==DgHandler))
                       {
                           return (dg == handler);
                       }
                       else
                       {
                           return false;
                       }
                   });
                   
                   if (equal)
                   {
                       return;
                   }
               }
               
               Handler h;
               
               h.set(handler);
                   
               (*arrayOfhandlers)~=h;
           }
           else
           {
               Handler h;
               
               h.set(handler);
               
               this.handlers[code]~=h;
           }
       }
    }
       
    /***************************************************************************
       
       Removes a handler from the list
       
       !!! Do not call this function from within a signal handler !!!
       
       Params:
           code    = signal that the handler is associate with
           handler = signal handler callback function
                     
       Template Params:
           T = type of the handler (delegate or function)
                   
       Throws:
           throws an Exception if the handler was not found
           
    ***************************************************************************/
    
    void unregister ( T )( int code, T handler )
    {
       unregister([code], handler);
    }
      
   /***************************************************************************
   
       Removes a handler from the list
       
       !!! Do not call this function from within a signal handler !!!
       
       Params:
           codes    = signals that the handler is associate with
           handler = signal handler callback function
               
       Template Params:
           T = type of the handler (delegate or function)
           
       Throws:
           throws an Exception if the handler was not found
    
    ***************************************************************************/
    
    public static void unregister ( T ) ( int[] codes, T handler )
    {        
        static if (!is(T == DgHandler) && !is(T == FnHandler))
        {
            static assert (false, "unregister template only usable for DgHandler or FnHandler!");
        }
        
        foreach (code ; codes)
        {
            if (auto hler = code in handlers)
            {
                foreach (i, h; *hler)
                {
                    bool break_ = h.visit((FnHandler fn)
                    {
                        static if (is(T==FnHandler))
                        {
                            if (fn == handler)
                            {
                                (*hler)[i] = (*hler)[$ - 1];
                                hler.length = hler.length - 1;
                                
                                return true;
                            }
                        }
                        return false;
                    },
                    (DgHandler dg)
                    {
                        static if (is(T==DgHandler))
                        {
                            if (dg == handler)
                            {
                                (*hler)[i] = (*hler)[$ - 1];
                                hler.length = hler.length - 1;
                                
                                return true;
                            }
                        }
                        return false;
                    } );
                    
                    if (break_)
                    {
                        break;
                    }
                }
            }
            else
            {
                throw new Exception("Signal handler not found!");
            }
        }
    }
   
   /****************************************************************************
   
       General signal handler. 
       This function is registered as signal handler for every signal that
       a callback has registered for. 
       
       It calls all callbacks for the signal and then — if none of the callbacks
       returned false — calls the default handler.
       
       Params:
           signal = the signal code
           
   ****************************************************************************/
   
   extern (C) private synchronized void sighandler ( int sig )
   {
       bool defaultHandler = true;
   
       assert(sig in handlers);
       
       foreach (d ; handlers[sig])
       {
           d.visit(
               (DgHandler dg) 
               {
                   if (!dg(sig))
                   {
                       defaultHandler = false;
                   }
               },
               (FnHandler fn) 
               {
                   if (!fn(sig))
                   {
                       defaultHandler = false;
                   }
               }
           );
       }

       if (defaultHandler)
       {           
           if (auto def = sig in this.default_handlers)
           {  
               signal(sig,*def);
               raise(sig);
           }
           else
           {
               assert(false, "Handler not registered");
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
            else
                assert(false);
        }
    }
    
	/**************************************************************************
    
        Returns the codes for which signal handlers are registered.
        
        Returns:
            list of codes
     
     **************************************************************************/

    int[] registered ( )
    {
        return this.handlers.keys.dup;
    }
    
    /**************************************************************************
    
        Returns the identifier string for signal code.
        
        Returns:
            identifier string for signal code
     
     **************************************************************************/

    char[] getId ( int code )
    {
        return Signals.description(code);
    }
}

