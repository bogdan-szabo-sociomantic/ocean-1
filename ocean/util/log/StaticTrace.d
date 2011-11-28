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

private import ocean.util.log.Trace;

private import ocean.io.Terminal;

private import tango.text.convert.Layout;

private import tango.text.Search;

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

        Find Fruct to find the \n's
    
    ***************************************************************************/

    private auto finder = find("\n");

    /***************************************************************************

        Outputs a thread-synchronized string to the console.
        
        Params:
            fmt = format string (same format as tanog.util.log.Trace)
            ... = variadic list of values referenced in format string

        Returns:
            this instance for method chaining
    
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

        size_t lines = 0;
        char[] nl = "";
        
        foreach ( token; this.finder.tokens(this.formatted) )
        {
            Trace.format("{}{}{}{}", nl, token, 
                         Terminal.CSI, Terminal.ERASE_REST_OF_LINE).flush;
        
            nl = "\n";
            
            lines++;
        }

        with (Terminal) if ( lines == 1 )
        {
            Trace.format("{}0{}", CSI, HORIZONTAL_MOVE_CURSOR).flush; 
        }
        else 
        {
            Trace.format("{}{}{}", CSI, lines - 1, LINE_UP).flush;
        }
        
        return this;
    }


    /***************************************************************************

        Flushes the output to the console.

        Returns:
            this instance for method chaining

    ***************************************************************************/

    public typeof(this) flush ( )
    {
        Trace.flush();
        return this;
    }
}

