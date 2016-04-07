/******************************************************************************

    Real time clock, obtains the current UNIX wall clock time in µs.

    Copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    Version:        November 2011: Initial release

    Author:         David Eckardt

 ******************************************************************************/

module ocean.time.MicrosecondsClock;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.stdc.posix.sys.time: timeval, gettimeofday;

/******************************************************************************/

class MicrosecondsClock
{
    /**************************************************************************

        timeval struct alias, defined as

        ---
        struct timeval
        {
            time_t tv_sec;  // UNIX time in s
            int    tv_usec; // µs in the current second
        }
        ---

     **************************************************************************/

    alias .timeval timeval;

    /**************************************************************************

        Returns:
            the current UNIX wall clock time in µs.

     **************************************************************************/

    static public ulong now_us ( )
    {
        return us(now);
    }

    /**************************************************************************

        Returns:
            the current UNIX wall clock time in µs.

     **************************************************************************/

    deprecated("Use now_us() instead")
    static public ulong now_us_static ( )
    {
        return us(now);
    }

    /**************************************************************************

        Usage tips: use

        ---
            MicrosecondsClock.now.tv_sec
        ---

        to obtain the UNIX timestamp of the current wall clock time or

        ---
            with (MicrosecondsClock.now.tv_sec)
            {
                // tv_sec:  UNIX timestamp of the current wall clock time
                // tv_usec: µs in the current second
            }
        ---

        to get the current UNIX time split into seconds and microseconds.

        Returns:
            the current UNIX wall clock time.

     **************************************************************************/

    static public timeval now ( )
    {
        timeval t;

        gettimeofday(&t, null);

        return t;
    }


    /**************************************************************************

        Converts t to a single integer value representing the number of
        microseconds.

        Params:
            t = timeval value to convert to single microseconds value

        Returns:
            number of microseconds

     **************************************************************************/

    static public ulong us ( timeval t )
    in
    {
        static if (is (t.tv_sec : int))
        {
            static assert (cast (ulong) t.tv_sec.max <                          // overflow check
                          (cast (ulong) t.tv_sec.max + 1) * 1_000_000);
        }
    }
    body
    {
        return t.tv_sec * 1_000_000UL + t.tv_usec;
    }
}
