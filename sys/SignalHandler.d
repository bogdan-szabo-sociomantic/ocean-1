/******************************************************************************

    Simple C/Posix Signals manager

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        Febrruary 2010: Initial release
    
    authors:        David Eckardt
    
    --
    
    Description:
    
    Register signal handlers for C/Posix Signals and, as an option, reset to
    default signal handlers.
    
 ******************************************************************************/
    
module ocean.sys.SignalHandlerRegistry;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import tango.stdc.signal: signal, SIGABRT, SIGFPE,  SIGILL,
                                          SIGINT,  SIGSEGV, SIGTERM;

version (Posix) private import tango.stdc.posix.signal: SIGALRM, SIGBUS,  SIGCHLD,
                                                        SIGCONT, SIGHUP,  SIGKILL,
                                                        SIGPIPE, SIGQUIT, SIGSTOP,
                                                        SIGTSTP, SIGTTIN, SIGTTOU,
                                                        SIGUSR1, SIGUSR2, SIGURG;

struct SignalHandler
{
    static:

    /**************************************************************************
    
        Signal handler type alias definition
     
     **************************************************************************/

    extern (C) alias void function ( int code ) SignalHandler;
    
    /**************************************************************************
    
        Signal enumerator
     
     **************************************************************************/

    version (Posix) enum : int
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
    else enum : int
    {
        SIGABRT   = .SIGABRT, // Abnormal termination
        SIGFPE    = .SIGFPE,  // Floating-point error
        SIGILL    = .SIGILL,  // Illegal hardware instruction
        SIGINT    = .SIGINT,  // Terminal interrupt character
        SIGSEGV   = .SIGSEGV, // Invalid memory reference
        SIGTERM   = .SIGTERM  // Termination
    }
    
    /**************************************************************************
    
        Default handlers registry to memorize the default handlers for reset
     
     **************************************************************************/

    synchronized private SignalHandler[int] default_handlers;
    
    /**************************************************************************
    
        Sets/registers handler for signal code.
        
        Params:
            code    = signal code to handle by handler
            handler = signal handler callback function
     
     **************************************************************************/

   void set ( int code, SignalHandler handler )
    {
        synchronized
        {
            SignalHandler prev_handler = signal(code, handler);
            
            if (!(code in this.default_handlers))
            {
                this.default_handlers[code] = prev_handler;
            }
        }
    }
    
   /**************************************************************************
   
       Resets handler for signal code to the default handler and unregisters
       the handler.
       
       Params:
           code = signal code
    
    **************************************************************************/

    void reset ( int code )
    {
        synchronized
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
}