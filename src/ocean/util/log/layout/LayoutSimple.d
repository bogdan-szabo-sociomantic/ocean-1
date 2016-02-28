/*******************************************************************************

    Simple Layout to be used with the tango logger

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        September 2011: Initial release

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.util.log.layout.LayoutSimple;

import ocean.transition;

import ocean.text.Util;

import ocean.time.Clock,
        ocean.time.WallClock;

import ocean.util.log.Log;

import  Integer = ocean.text.convert.Integer_tango;


/*******************************************************************************

        A simple layout, prefixing each message with the log level and
        the name of the logger.

        Example:
        ------
        import ocean.util.log.layout.LayoutSimple;
        import ocean.util.log.Log;
        import ocean.util.log.AppendConsole;


        Log.root.clear;
        Log.root.add(new AppendConsole(new LayoutSimple));

        auto logger = Log.lookup("Example");

        logger.trace("Trace example");
        logger.error("Error example");
        logger.fatal("Fatal example");
        -----

        Produced output:
        -----
        Trace [Example] - Trace example
        Error [Example] - Error example
        Fatal [Example] - Fatal example
        ----

*******************************************************************************/

public class LayoutSimple : Appender.Layout
{
        /***********************************************************************

                Subclasses should implement this method to perform the
                formatting of the actual message content.

        ***********************************************************************/

        void format (LogEvent event, size_t delegate(Const!(void)[]) dg)
        {
                auto level = event.levelName;

                // format date according to ISO-8601 (lightweight formatter)
                char[20] tmp = void;
                char[256] tmp2 = void;
                dg (layout (tmp2, "%0 [%1] - ",
                            level,
                            event.name
                            ));
                dg (event.toString);
        }

        /**********************************************************************

                Convert an integer to a zero prefixed text representation

        **********************************************************************/

        private cstring convert (mstring tmp, long i)
        {
                return Integer.formatter (tmp, i, 'u', '?', 8);
        }
}
