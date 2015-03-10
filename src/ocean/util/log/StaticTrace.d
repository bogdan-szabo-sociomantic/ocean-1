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

import ocean.core.TypeConvert;

import ocean.io.Terminal;

import tango.text.convert.Layout;

import tango.text.Search;

import tango.io.model.IConduit;

import tango.io.Console;

/*******************************************************************************

 Platform issues ...

*******************************************************************************/

version (GNU)
{
    import tango.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;
}
else version (LDC)
{
    import tango.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;
}
else version (DigitalMars)
{
    import tango.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;

    version (X86_64) version = DigitalMarsX64;
}
else
{
    alias void* Arg;
    alias void* ArgList;
}

/*******************************************************************************

    Construct StaticTrace when this module is loaded

*******************************************************************************/

/// global static trace instance
public static StaticSyncPrint StaticTrace;

static this()
{
    StaticTrace = new StaticSyncPrint(Cerr.stream);
}



/*******************************************************************************

    Static trace class - internal only

*******************************************************************************/

public class StaticSyncPrint
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

        Outputstream to use.

    ***************************************************************************/

    private OutputStream output;

    /***************************************************************************

        C'tor

        Params:
            output = Outputstream to use.

    ***************************************************************************/

    public this ( OutputStream output )
    {
        this.output = output;
    }

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
            return castFrom!(size_t).to!(uint)(s.length);
        }

        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            Layout!(char).instance()(&sink, _arguments, ap, fmt);
        }
        else
            Layout!(char).instance()(&sink, _arguments, _argptr, fmt);

        size_t lines = 0;
        char[] nl = "";

        foreach ( token; this.finder.tokens(this.formatted) )
        {
            with ( this.output )
            {
                write(nl);
                write(token);
                write(Terminal.CSI);
                write(Terminal.ERASE_REST_OF_LINE);
                flush();
            }

            nl = "\n";

            lines++;
        }

        with (Terminal) if ( lines == 1 )
        {
            with ( this.output )
            {
                write(CSI);
                write("0");
                write(HORIZONTAL_MOVE_CURSOR);
                flush();
            }
        }
        else with ( this.output )
        {
            formatted.length = 0;
            Layout!(char).instance()(&sink, "{}", lines - 1);

            write(CSI);
            write(formatted);
            write(LINE_UP);
            flush();
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
        this.output.flush();
        return this;
    }
}

