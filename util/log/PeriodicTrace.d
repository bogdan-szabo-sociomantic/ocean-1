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

    The struct defaults to a line-by-line update (using Trace.formatln) updated
    every 1/10 of a second.

    Note: this struct automatically calls Trace.flush / StaticTrace.flush after
    updating.

    Usage example:
    
    ---

        private import ocean.util.log.PeriodicTrace;

        PeriodicTrace trace;
        trace.interval = 500_000; // only update display after at least half a second has passed
        trace.static_display = true;

        for ( uint i; i < uint.max; i++ )
        {
            trace.format("{}", i).flush;
        }

    ---

*******************************************************************************/

module ocean.util.log.PeriodicTrace;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.log.StaticTrace;

private import tango.util.log.Trace;

private import tango.text.convert.Layout;

private import tango.time.StopWatch;



/*******************************************************************************

    PeriodicTrace struct.

*******************************************************************************/

struct PeriodicTrace
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
        if ( this.timeToUpdate() )
        {
            this.last_update_time = this.now;

            this.formatted.length = 0;
            uint sink ( char[] s )
            {
                this.formatted ~= s;
                return s.length;
            }

            Layout!(char).instance()(&sink, _arguments, _argptr, fmt);

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

