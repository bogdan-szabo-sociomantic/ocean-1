/******************************************************************************

    Interface for a class that obtains the current UNIX wall clock time in µs.

    Copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    Version:        November 2011: Initial release

    Author:         David Eckardt

 ******************************************************************************/

module ocean.time.model.IMicrosecondsClock;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.stdc.posix.sys.time : timeval;
private import tango.stdc.time : tm, time_t;
private import tango.time.Time;



/*******************************************************************************

    Basic microseconds clock, with a single method to get the time now in µs.

*******************************************************************************/

interface IMicrosecondsClock
{
    /**************************************************************************

        Returns:
            the current UNIX wall clock time in µs.

     **************************************************************************/

    ulong now_us ( );
}



/*******************************************************************************

    Extends the basic microseconds clock, adding additional methods to get the
    time in different formats.

*******************************************************************************/

interface IAdvancedMicrosecondsClock : IMicrosecondsClock
{
    /**************************************************************************

        Returns:
            a time value between the current system time t and
            t + this.interval_.

     **************************************************************************/

    timeval now_timeval ( );


    /**************************************************************************

        Returns:
            the time now in seconds

     **************************************************************************/

    time_t now_sec ( );


    /**************************************************************************

        Gets the current time as tm struct.

        Params:
            local = true: return local time, false: return GMT.

        Returns:
            the current time as tm struct.

        Out:
            DST can be enabled with local time only.

     **************************************************************************/

    tm now_tm ( bool local = false );


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

    tm now_tm ( out uint us, bool local = false );


    /**************************************************************************

        Gets the current time in terms of the year, months, days, hours, minutes
        and seconds.

        Returns:
            DateTime struct containing everything.

     **************************************************************************/

    DateTime now_DateTime ( );
}



