/*******************************************************************************

    Periodic console tracer

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        December 2010: Initial release
    
    authors:        Gavin Norman
    
    Periodic console tracer - writes messages to the console limited to a
    specified update interval. This can be used to safely limit the number of
    writes to the console. The write is done using either tango.util.log.Trace
    or ocean.util.log.StaticTrace, depending on the value of the struct's
    static_display member.

    Note: this struct automatically calls Trace.flush / StaticTrace.flush after
    updating.

    Two global instances of this struct exist for convenience: PeriodicTrace and
    StaticPeriodicTrace. The latter has the static_display flag set to true.

    Usage example with the global instance:

    ---

        private import ocean.util.log.PeriodicTrace;

        const ulong trace_interval = 500_000; // only update display after at least half a second has passed

        for ( uint i; i < uint.max; i++ )
        {
            StaticPeriodicTrace.format(trace_interval, "{}", i);
        }

    ---

    A local instance of the PeriodicTracer struct may be useful in situations
    where two or more separate periodic outputs are required each with a 
    different update interval.

    Usage example with a local instance:
    
    ---

        private import ocean.util.log.PeriodicTrace;

        PeriodicTrace trace1;
        trace1.interval = 500_000; // only update display after at least half a second has passed

        PeriodicTrace trace2;
        trace2.interval = 5_000_000; // only update display after at least 5 seconds have passed

        for ( uint i; i < uint.max; i++ )
        {
            trace1.format("{}", i);
            trace2.format("{}", i);
        }

    ---

*******************************************************************************/

module ocean.util.log.PeriodicTrace;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.log.StaticTrace;

private import tango.stdc.stdarg;

private import tango.util.log.Trace;

private import tango.text.convert.Layout;

private import tango.time.StopWatch;



/*******************************************************************************

    Two shared instances of the PeriodicTracer struct, one with a normal
    "streaming" display via Trace, and one with a static updating display via
    StaticTrace.

*******************************************************************************/

public PeriodicTracer PeriodicTrace;

public PeriodicTracer StaticPeriodicTrace;

static this ( )
{
    StaticPeriodicTrace.static_display = true;
}



/*******************************************************************************

    PeriodicTracer struct.

*******************************************************************************/

struct PeriodicTracer
{
    /***************************************************************************
    
        Minimum time between updates (microsec)
    
    ***************************************************************************/
    
    public ulong interval = 100_000; // defaults to 1/10 of a second
    
    
    /***************************************************************************
    
        Toggles between static display (true) and line-by-line display (false)
    
    ***************************************************************************/
    
    public bool static_display;


    /***************************************************************************
    
        Timer, shared by all instances of this struct (there's only one time!)
    
    ***************************************************************************/
    
    static public StopWatch timer;
    
    
    /***************************************************************************
    
        The maximum size of string displayed to the console so far. This is
        recorded so that static displays can cleanly overwrite previous content.
    
    ***************************************************************************/
    
    private uint max_strlen;
    
    
    /***************************************************************************
    
        Time of last update
    
    ***************************************************************************/
    
    private ulong last_update_time;
    
    
    /***************************************************************************
    
        Time retrieved by the most recent call to timeToUpdate()
    
    ***************************************************************************/
    
    private ulong now;
    

    /***************************************************************************
    
        Buffer for string formatting.
    
    ***************************************************************************/

    private char[] formatted;
    

    /***************************************************************************

        Outputs a formatted string to the console if the update interval has
        passed. The display is either static or adds a newline depending on the
        this.static_display member.

        Params:
            fmt = format string (same format as tanog.util.log.Trace)
            ... = variadic list of values referenced in format string

        Returns:
            this instance for method chaining

    ***************************************************************************/

    public typeof(this) format ( char[] fmt, ... )
    {
        return this.format(fmt, _argptr, _arguments);
    }


    /***************************************************************************

        Outputs a formatted string to the console if the specified update
        interval has passed. The display is either static or adds a newline
        depending on the this.static_display member.

        Params:
            interval = minimum interval between display updates
            fmt = format string (same format as tanog.util.log.Trace)
            ... = variadic list of values referenced in format string

        Returns:
            this instance for method chaining

    ***************************************************************************/

    public typeof(this) format ( ulong interval, char[] fmt, ... )
    {
        this.interval = interval;
        return this.format(fmt, _argptr, _arguments);
    }


    // TODO: flush() method


    /***************************************************************************
    
        Checks if it's time to update the display.
        
        Note: this method is public so that using classes can determine whether
        they need to perform any internal update before calling display().
        
        TODO: this would be better done with a lazy char[] version of format(),
        which only calls the lazy delegate if it *is* time to update.

        Returns:
            true if the display update interval has passed
    
    ***************************************************************************/
    
    public bool timeToUpdate ( )
    {
        this.now = timer.microsec();
        return this.now > this.last_update_time + this.interval;
    }


    /***************************************************************************

        Outputs a formatted string to the console if the update interval has
        passed. The display is either static or adds a newline depending on the
        this.static_display member.
    
        Params:
            fmt = format string (same format as tanog.util.log.Trace)
            args = argument pointers
            types = argument types
    
        Returns:
            this instance for method chaining
    
    ***************************************************************************/
    
    private typeof(this) format ( char[] fmt, va_list args, TypeInfo[] types )
    {
        if ( this.timeToUpdate() )
        {
            this.last_update_time = this.now;
    
            this.formatted.length = 0;
            uint sink ( char[] s )
            {
                this.formatted ~= s;
                return s.length;
            }
    
            Layout!(char).instance()(&sink, types, args, fmt);
    
            if ( this.static_display )
            {
                this.padToMax(this.formatted);
    
                StaticTrace.format("{}", this.formatted).flush;
            }
            else
            {
                Trace.formatln("{}", this.formatted).flush;
            }
        }
    
        return this;
    }


    /***************************************************************************

        Checks whether the passed string is longer than the previous longest
        string. If it is shorter then it is padded with spaces to match the
        length of the previous longest string. This is done so that statically
        displayed strings won't have any erroneous characters to their right.

        Returns:
            true if the display update interval has passed

    ***************************************************************************/

    private void padToMax ( ref char[] string )
    {
        if ( string.length < this.max_strlen )
        {
            auto len = string.length;
            string.length = this.max_strlen;
            string[len..$] = ' ';
        }
        else
        {
            max_strlen = string.length;
        }
    }


    /***************************************************************************
    
        Static constructor, starts the shared timer.
    
    ***************************************************************************/
    
    static this ( )
    {
        timer.start();
    }
}

