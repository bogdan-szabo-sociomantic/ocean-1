/*******************************************************************************

        copyright:      Copyright (c) 2007 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Oct 2007: Initial release

        author:         Kris

        Synchronized, formatted console output. Usage is:
        ---
        Trace.formatln ("hello {}", "world");
        ---

        Note that this has become merely a wrapper around Log.formatln(), so
        please use that API instead

*******************************************************************************/

deprecated module tango.util.log.Trace;

pragma(msg, "Use Log instead of Trace or set the root logger from your main");

public import tango.util.log.Config;

/*******************************************************************************

        redirect to the Log module

*******************************************************************************/

public alias Log Trace;

/*******************************************************************************

*******************************************************************************/

debug (Trace)
{
        void main()
        {
                Trace.formatln ("hello {}", "world");
                Trace ("hello {}", "world");
        }
}
