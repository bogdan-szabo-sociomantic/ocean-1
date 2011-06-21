/******************************************************************************

    Real time clock that, after it has queried the system clock, waits until a
    time interval has expired before querying the system clock again.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    Usage example:

    ---

        import ocean.io.select.event.IntervalClock;
        import ocean.io.select.EpollSelectDispatcher;
        
        scope dispatcher = new EpollSelectDispatcher;
        
        scope clock = new IntervalClock;
        
        clock.interval_ms = 100;
        
        dispatcher.register(clock).eventLoop();

        // At this point, the first call to clock.now() will query the system
        // time while subsequent calls within the next 100 ms will return the
        // same value. The first call after 100 ms will then query the system
        // time again.

    ---
    
 ******************************************************************************/

module ocean.io.select.event.IntervalClock;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.event.TimerEvent;

private import tango.stdc.stdlib: div;

private import tango.stdc.posix.sys.time: timeval, timespec, gettimeofday;

private import tango.io.Stdout;

class IntervalClock : ITimerEvent
{
    /**************************************************************************

        Timer update interval. now() will keep returning the same value during
        this amount of time.
        
        Default: 1 s.
    
     **************************************************************************/

    public timeval interval = timeval(1);
    
    /**************************************************************************

        true: now() should obtain the system time.
        false: now() should return the same value as it did last time.
        
        Cleared by now() and set by handle_().
    
     **************************************************************************/

    private bool expired = true;
    
    /**************************************************************************

        System time value most recently obtained by now().
    
     **************************************************************************/

    private timeval t;
    
    /**************************************************************************
    
        Constructor
    
     **************************************************************************/

    this ( )
    {
        super(true);
        super.absolute = true;
    }
    
    /**************************************************************************
    
        Returns:
            a time value between the current system time t and
            t + this.interval.  
    
     **************************************************************************/

    timeval now ( )
    out (t)
    {
        Stderr(' ')(t.tv_sec)('\n').flush();
    }
    body
    {
        Stderr("\t" ~ typeof (this).stringof ~ ": ")(expired);
        
        if (this.expired)
        {
            gettimeofday(&this.t, null);
            this.expired = false;
            with (this.timeval_add(this.t, this.interval))
            {
                super.set(timespec(tv_sec, tv_usec * 1000));
            }
        }
        
        return this.t;
    }
    
    /**************************************************************************
    
        Sets the time interval in seconds.
        
        To get the time interval in seconds use interval.tv_sec.
       
        Params:
            s = new time interval in seconds
            
        Returns:
            s
    
     **************************************************************************/

    public time_t interval_s ( time_t s )
    {
        this.interval.tv_usec = 0;
        return this.interval.tv_sec = s;
    }
    
    /**************************************************************************
    
        Returns:
            the time interval in milliseconds
    
     **************************************************************************/

    public ulong interval_ms ( )
    {
        with (this.interval)
        {
            return (tv_sec * 1000UL) + (tv_usec / 1000UL);
        }
    }
    
    /**************************************************************************
    
        Sets the time interval in milliseconds.
        
        Params:
            ms = new time interval in seconds
            
        Returns:
            ms
    
     **************************************************************************/

    public uint interval_ms ( uint ms )
    {
        with (div(ms, 1000))
        {
            this.interval.tv_sec  = quot;
            this.interval.tv_usec = rem * 1_000;
        }
        
        return ms;
    }
    
    /**************************************************************************
    
        Timer event handler
    
     **************************************************************************/

    protected bool handle_ ( ulong n )
    {
        Stderr("\t" ~ typeof (this).stringof ~ " expired\n").flush();
        this.expired = true;
        return true;
    }
    
    /**************************************************************************
    
        Adds a and b.
        
        Params:
            a = timeval summand
            b = timeval summand
            
        Returns:
            a + b
        
        In:
            a.tv_usec + b.tv_usec must not overflow
        
     **************************************************************************/

    static timeval timeval_add ( timeval a, timeval b )
    in                                                                          // overflow check
    {
        auto usec = a.tv_usec + b.tv_usec;
        assert (usec >= a.tv_usec);
        assert (usec >= b.tv_usec);
    }
    out (c)
    {
        assert (c.tv_usec < 1_000_000);
    }
    body
    {
        timeval c;
        
        with (div(a.tv_usec + b.tv_usec, 1_000_000))
        {
            c.tv_sec  = a.tv_sec + b.tv_sec + quot;
            c.tv_usec = rem;
        }
        
        return c;
    }
    
    /**************************************************************************
    
        Returns:
            class identifier string for select dispatcher debugging
        
     **************************************************************************/

    debug char[] id ( )
    {
        return typeof (this).stringof;
    }
}
