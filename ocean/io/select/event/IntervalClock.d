/******************************************************************************

    Real time clock that, after it has queried the system clock, waits until a
    time interval_ has expired before querying the system clock again.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        David Eckardt

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

    This module makes use of several different structs for time representation:

        struct timeval
        {
            time_t tv_sec; // current time in seconds (unix time)
            int tv_usec;   // fractional part of time, in microseconds
        }

        struct tm
        {
          int tm_sec;			// Seconds.	[0-60] (1 leap second)
          int tm_min;			// Minutes.	[0-59]
          int tm_hour;			// Hours.	[0-23]
          int tm_mday;			// Day.		[1-31]
          int tm_mon;			// Month.	[0-11]
          int tm_year;			// Year	- 1900.
          int tm_wday;			// Day of week.	[0-6]
          int tm_yday;			// Days in year.[0-365]
          int tm_isdst;			// DST.		[-1/0/1]
        };

        struct DateTime (see tango.time.DateTime)

 ******************************************************************************/

module ocean.io.select.event.IntervalClock;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.event.TimerEvent;

private import ocean.time.model.IMicrosecondsClock,
               ocean.time.MicrosecondsClock;

private import tango.stdc.stdlib: div;

private import tango.stdc.posix.sys.time: timeval, timespec, gettimeofday;
private import tango.stdc.posix.time:     gmtime_r, localtime_r;
private import tango.stdc.time:           gmtime, tm, time_t;

private import tango.time.Time;

public class IntervalClock : ITimerEvent, IMicrosecondsClock
{
    public alias MicrosecondsClock.us us;
    
    /**************************************************************************

        Timer update interval_. All now*() methods will keep returning the same
        value during this amount of time.
        
        If set to zero, that is, all member values are 0, the system time is
        queried on every call of any of the now*() methods.
        
        Default: 1 s.
    
     **************************************************************************/

    private timeval interval_ = timeval(1);
    
    /**************************************************************************

        true: now() should obtain the system time.
        false: now() should return the same value as it did last time.
        
        Set by handle_() and, if interval_ is not zero, cleared by
        now_timeval(), which is called by all other now*() methods.
    
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

    public timeval now_timeval ( )
    {
        if (this.expired)
        {
            this.t = MicrosecondsClock.now;
            
            ulong interval_us = this.us(this.interval_),
                  t_us        = this.us(this.t);
            
            /*
             * If this.interval_ is not zero, set the expired flag to false and
             * schedule next expiration. Otherwise leave the expired flag true
             * and do not schedule. 
             */
            
            with (this.interval_) if (tv_sec || tv_usec)
            {
                // Truncate the time to the interval resolution.
                
                t_us /= interval_us;
                t_us *= interval_us;
                
                ulong next_us = t_us + interval_us;
                
                this.expired = false;
                
                super.set(timespec(cast (uint) (next_us / 1_000_000),
                                   cast (uint) (next_us % 1_000_000) * 1_000));
            }
            
            with (this.t)
            {
                tv_sec  = cast (uint) (t_us / 1_000_000);
                tv_usec = cast (uint) (t_us % 1_000_000);
            }
        }
        
        return this.t;
    }

    /**************************************************************************
    
        Returns:
            the time now in seconds

     **************************************************************************/

    public time_t now_sec ( )
    {
        return this.now_timeval.tv_sec;
    }

    /**************************************************************************
    
        Returns:
            the time now in microseconds

     **************************************************************************/

    public ulong now_us ( )
    {
        return this.us(this.now_timeval);
    }

    /**************************************************************************
    
        Gets the current time as tm struct.
    
        Params:
            local = true: return local time, false: return GMT.
        
        Returns:
            the current time as tm struct.
            
        Out:
            DST can be enabled with local time only.
        
     **************************************************************************/

    public tm now_tm ( bool local = false )
    {
        return this.toTm(this.now_timeval.tv_sec);
    }

    /**************************************************************************
    
        Gets the current time as tm struct, and the microseconds within the
        current second as an out parameter.

        Params:
            us = receives the number of microseconds in the current second
            local = true: return local time, false: return GMT.

        Returns:
            the current time as tm struct.

        Out:
            DST can be enabled with local time only.

     **************************************************************************/

    public tm now_tm ( out uint us, bool local = false )
    {
        with (this.now_timeval)
        {
            us = tv_usec;
            
            return this.toTm(tv_sec);
        }
    }
    
    /**************************************************************************
    
        Gets the current time in terms of the year, months, days, hours, minutes
        and seconds.

        Returns:
            DateTime struct containing everything.

     **************************************************************************/
    
    public DateTime now_DateTime ( )
    {
        with (this.now_timeval) with (this.toTm(tv_sec))
        {
            DateTime dt;
            
            dt.date.day   = tm_mday;
            dt.date.year  = tm_year + 1900;
            dt.date.month = tm_mon  + 1;
            dt.date.dow   = tm_wday;
            dt.date.doy   = tm_yday + 1;
            
            dt.time.hours   = tm_hour;
            dt.time.minutes = tm_min;
            dt.time.seconds = tm_sec;
            dt.time.millis  = tv_usec / 1000;
            
            return dt;
        }
    }
    
    /**************************************************************************
    
        Sets the time interval in seconds.
        
        To get the time interval in seconds use interval_.tv_sec.
       
        Params:
            s = new time interval in seconds
            
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
            the time interval in milliseconds
    
     **************************************************************************/

    public ulong interval_ms ( )
    {
        with (this.interval_)
        {
            return (tv_sec * 1000UL) + (tv_usec / 1000UL);
        }
    }
    
    /**************************************************************************
    
        Sets the time interval in milliseconds.
        
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
    
        Converts t to a tm struct value, split into year, months, days, hours,
        minutes and seconds.
    
        Params:
            t     = UNIX time in seconds
            local = true: return local time, false: return GMT.
        
        Returns:
            the t as tm struct.
            
        Out:
            DST can be enabled with local time only.
    
     **************************************************************************/

    public static tm toTm ( time_t t, bool local = false )
    out (datetime)
    {
        assert (local || datetime.tm_isdst <= 0, "DST enabled with GMT");
    }
    body
    {
        tm datetime;
        
        (local? &localtime_r : &gmtime_r)(&t, &datetime);                       // actually one should check the return value
                                                                                // of localtime_r() gmtime_r() but in this
        return datetime;                                                        // usage they should never fail ;)
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
