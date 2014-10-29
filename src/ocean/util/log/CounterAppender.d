/*******************************************************************************

    Counts how often a certain type of logger has been used

    copyright:      Copyright (c) 2009-2011 sociomantic labs.
                    All rights reserved

    version:        June 2011: initial release

    authors:        Mathias L. Baumann

*******************************************************************************/

module ocean.util.log.CounterAppender;

import tango.util.log.Log;

/*******************************************************************************

    Counts how often a certain type of logger has been used

*******************************************************************************/

public class CounterAppender : Appender
{
        private Mask mask_;

        /***********************************************************************

                Arraymap containing the counters

        ***********************************************************************/

        private static size_t[char[]] counter;

        /***********************************************************************


        ***********************************************************************/

        this ( )
        {
                mask_ = register (name);
        }

        /***********************************************************************

                Return the fingerprint for this class

        ***********************************************************************/

        final Mask mask ()
        {
                return mask_;
        }

        /***********************************************************************

                Return the name of this class

        ***********************************************************************/

        final char[] name ()
        {
                return this.classinfo.name;
        }

        /***********************************************************************

                Append an event to the output.

        ***********************************************************************/

        final void append (LogEvent event)
        {
              counter[event.name]++;
        }

        /***********************************************************************

            Returns the value of the counter of the given logger.
            Resets the value before returning it.

            Params:
                name = name of the logger

            Returns:
                the value of the counter

        ***********************************************************************/

        static public size_t opIndex ( char[] name )
        {
            auto v = name in counter;

            if ( v is null ) return 0;

            auto ret = *v;

            *v = 0;

            return ret;
        }

        /***********************************************************************

            Returns the value of the counter of the given logger

            Params:
                name = name of the logger
                reset = whether to reset the counter

            Returns:
                the value of the counter

        ***********************************************************************/

        static public size_t get ( char[] name, bool reset = true )
        {
            auto v = name in counter;

            if ( v is null ) return 0;

            auto ret = *v;

            if ( reset ) *v = 0;

            return ret;
        }

}