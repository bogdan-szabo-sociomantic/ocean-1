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
                more = retry(e);    // Retry up to 10 times, then rethrow e
            }
        }
        while (more)
        
    ---
    
 ******************************************************************************/

module ocean.io.Retry;

private import Ctime  = tango.stdc.posix.time:      nanosleep;
private import Ctimer = tango.stdc.posix.timer:     timespec;
private import          tango.stdc.time:            time_t;

class Retry
{
    /**************************************************************************
    
        Callback method type aliases 
    
     **************************************************************************/
    
    public alias bool delegate ( char[] message ) CallbackDelg;
    public alias bool function ( char[] message ) CallbackFunc;

    /**************************************************************************
    
        Callback union
        
        Holds the callback method reference (either delegate or function)
      
     **************************************************************************/

    union Callback
    {
        Retry.CallbackDelg delg;
        Retry.CallbackFunc func;
    }
    
    /**************************************************************************
    
        Parameters for default wait/retry callback method; may be changed at any
        time
        
        These are effective if the default wait/retry callback method is used.
        
        enabled = do retry
        ms      = time to wait before each retry
        retries = maximum number of consecutive retries; 0 = unlimited
        
     **************************************************************************/
    
    public bool enabled = true;
    public uint ms      = 500;
    public uint retries = 0;
    
    private uint n = 0;
    
    /**************************************************************************
    
        This alias for method chaining
    
     **************************************************************************/
    
    private alias typeof (this) This;
    
    /**************************************************************************
    
        callback method reference
      
     **************************************************************************/

    private Callback callback;
    
    /**************************************************************************
    
        "callback is delegate flag"
        
        true: callback holds a delegate; false: callback holds a function
      
     **************************************************************************/

    private bool callback_is_delg;
    
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
            n  = default retry callback: maximum number of retries
       
    **************************************************************************/
    
    public this ( uint ms, uint retries )
    {
        this();
        
        this.ms       = ms;
        this.retries  = retries;
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
        return this.callback_is_delg? this.callback.delg(message) :
                                      this.callback.func(message);
    }
    
    /**************************************************************************
        
        Calls the retry callback method and rethrows e if the callback indicates
        no retrying.
        
        Params:
            e = exception caught on previously failed operation
    
    ****************************************************************/
    
    public void opCall ( Exception e )
    {
        bool retry = this.callback_is_delg? this.callback.delg(e.msg) :
                                            this.callback.func(e.msg);
        
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
            
     ***************************************************************/
    
    public This opAssign ( CallbackDelg delg )
    {
        this.callback.delg = delg;
        this.callback_is_delg   = true;
        
        return this;
    }
    
    
    /**************************************************************************
    
        Sets the callback method.
        
        Params:
             func = callback method function reference
             
        Returns:
             this instance
             
      **************************************************************************/
    
    public This opAssign ( CallbackFunc func )
    {
        this.callback.func    = func;
        this.callback_is_delg = false;
        
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
    
    /**************************************************************************
    
        Default retry callback method for push/pop retries
                
        Params:
            message = error message
        
        Returns:
            true if the caller shall continue trying or false if the caller
            shall quit
                  
     **************************************************************************/
    
    public bool wait ( char[] message )
    {
        // Is retry enabled and are we below the retry limit or unlimited?
        bool retry = this.enabled && ((this.n < this.retries) || !this.retries);
        
        if (retry)
        {
            this.n++;
            
            this.sleep(this.ms);
        }
        
        return retry;
    }
    
    /**************************************************************************
    
        Sleep in a multi-thread compatible way.
        sleep() in multiple threads is not trivial because when several threads
        simultaneously sleep and the first wakes up, the others will instantly
        wake up, too. See nanosleep() man page
        
        http://www.kernel.org/doc/man-pages/online/pages/man2/nanosleep.2.html
        
        or
        
        http://www.opengroup.org/onlinepubs/007908799/xsh/nanosleep.html
        
        Params:
            ms = milliseconds to sleep
    
     **************************************************************************/


    static void sleep ( time_t ms )
    {
        auto ts = Ctimer.timespec(ms / 1_000, (ms % 1_000) * 1_000_000);
        
        while (Ctime.nanosleep(&ts, &ts)) {}
    }
}