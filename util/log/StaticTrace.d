/*******************************************************************************

    Static console tracer

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        November 2010: Initial release
    
    authors:        Gavin Norman
    
    Static console tracer - moves the cursor back to its original position after
    printing the required text.

*******************************************************************************/

module ocean.util.log.StaticTrace;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.util.log.Trace;

private import tango.text.convert.Layout;



/*******************************************************************************

    Construct StaticTrace when this module is loaded

*******************************************************************************/

/// global static trace instance
public static StaticSyncPrint StaticTrace;

static this()
{
    StaticTrace = new StaticSyncPrint();
}



/*******************************************************************************

    Static trace class - internal only

*******************************************************************************/

private class StaticSyncPrint
{
    /***************************************************************************

        Buffer used for string formatting.
    
    ***************************************************************************/

    private char[] formatted;


    /***************************************************************************

        Outputs a thread-synchronized string to the console.
        
        Params:
            fmt = format string (same format as tanog.util.log.Trace)
            ... = variadic list of values referenced in format string
    
    ***************************************************************************/

    synchronized public typeof(this) format ( char[] fmt, ... )
    {
        formatted.length = 0;
        uint sink ( char[] s )
        {
            formatted ~= s;
            return s.length;
        }

        Layout!(char).instance()(&sink, _arguments, _argptr, fmt);

        auto len = formatted.length;
        formatted.length = formatted.length * 2;
        formatted[len..$] = '\b';

        Trace.format("{}", formatted);

        return this;
    }


    public typeof(this) flush ( )
    {
        Trace.flush();
        return this;
    }
}

