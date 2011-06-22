/******************************************************************************

    Real time clock that, after it has queried the system clock, waits until a
    time interval_ has expired before querying the system clock again.

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

class IntervalClock : ITimerEvent
{
    /**************************************************************************

        Timer update interval_. now() will keep returning the same value during
        this amount of time.
        
        Default: 1 s.
    
     **************************************************************************/

    private timeval interval_ = timeval(1);
    
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
    
        Sets the interval.
        
        Params:
            interval_ = new interval
        
        Returns:
            interval_
    
     **************************************************************************/
    
    timeval interval ( timeval interval_ )
    {
        this.expired = true;
        return this.interval_ = interval_;
    }

    /**************************************************************************
    
        Returns:
            current interval
    
     **************************************************************************/

    timeval interval ( )
    {
        return this.interval_;
    }
    
    /**************************************************************************
    
        Returns:
            a time value between the current system time t and
            t + this.interval_.  
    
     **************************************************************************/

    timeval now ( )
    {
        if (this.expired)
        {
            gettimeofday(&this.t, null);
            
            this.expired = false;
            
            ulong interval_us = this.us(this.interval_),
                  t_us        = this.us(this.t) / interval_us * interval_us,
                  next_us     = t_us + interval_us;
            
            with (this.t)
            {
                tv_sec  = cast (uint) (t_us / 1_000_000);
                tv_usec = cast (uint) (t_us % 1_000_000);
            }
            
            super.set(timespec(cast (uint) (next_us / 1_000_000),
                               cast (uint) (next_us % 1_000_000) * 1_000));
        }
        
        return this.t;
    }
    
    /**************************************************************************
    
        Sets the time interval_ in seconds.
        
        To get the time interval_ in seconds use interval_.tv_sec.
       
        Params:
            s = new time interval_ in seconds
            
        Returns:
            s
    
     **************************************************************************/

    public time_t interval_s ( time_t s )
    {
        this.interval_.tv_usec = 0;
        return this.interval_.tv_sec = s;
    }
    
    /**************************************************************************
    
        Returns:
            the time interval_ in milliseconds
    
     **************************************************************************/

    public ulong interval_ms ( )
    {
        with (this.interval_)
        {
            return (tv_sec * 1000UL) + (tv_usec / 1000UL);
        }
    }
    
    /**************************************************************************
    
        Sets the time interval_ in milliseconds.
        
        Params:
            ms = new time interval_ in seconds
            
        Returns:
            ms
    
     **************************************************************************/

    public uint interval_ms ( uint ms )
    {
        with (div(ms, 1000))
        {
            this.interval_.tv_sec  = quot;
            this.interval_.tv_usec = rem * 1_000;
        }
        
        return ms;
    }
    
    /**************************************************************************
    
        Timer event handler
    
     **************************************************************************/

    protected bool handle_ ( ulong n )
    {
        this.expired = true;
        return true;
    }
    
    /**************************************************************************
        
        Converts t to a single integer value representing the number of
        microseconds.
        
        Params:
            t = timeval value to convert to single microseconds value
        
        Returns:
            number of microseconds
    
     **************************************************************************/
    
    static ulong us ( timeval t )
    in
    {
        static assert (cast (ulong) t.tv_sec.max <                              // overflow check
                       (cast (ulong) t.tv_sec.max + 1) * 1_000_000);
        
    }
    body
    {
        return t.tv_sec * 1_000_000UL + t.tv_usec;
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
