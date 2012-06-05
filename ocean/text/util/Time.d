/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    authors:        Gavin Norman

    Functions to format time strings.

    Usage exmaple:

    ---

        import ocean.text.util.Time;

        char[] str;

        uint seconds = 94523;

        formatDuration(seconds, str);

        // str will now hold the string "1 day, 2 hours, 15 minutes, 23 seconds"

        formatDurationShort(seconds, str);

        // str will now hold the string "1d2h15m23s"

    ---

*******************************************************************************/

module ocean.text.util.Time;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.text.convert.Layout;

private import ocean.core.Array : copy;



/*******************************************************************************

    Formats a string with the number of years, days, hours, minutes & seconds
    specified.

    Params:
        s = number of seconds elapsed
        output = destination string buffer

    Returns:
        formatted string

*******************************************************************************/

public char[] formatDuration ( uint s, ref char[] output )
{
    output.length = 0;

    bool comma = false;

    /***************************************************************************

        Appends the count of the specified value to the output string, if the
        value is > 0. Also appends a comma first, if this is not the first value
        to be appended to the output string. In this way, a comma-separated list
        of values is built up over multiple calls to this function.

        Params:
            number = value to append
            name = name of quantity

    ***************************************************************************/

    void append ( uint number, char[] name )
    {
        if ( number > 0 )
        {
            if ( comma ) output ~= ", ";
            Layout!(char).print(output, "{} {}{}", number, name,
                number > 1 ? "s" : "");
            comma = true;
        }
    }

    if ( s == 0 )
    {
        output.copy("0 seconds");
    }
    else
    {
        uint years, days, hours, minutes, seconds;
        extractTimePeriods(s, years, days, hours, minutes, seconds);

        append(years,   "year");
        append(days,    "day");
        append(hours,   "hour");
        append(minutes, "minute");
        append(seconds, "second");
    }

    return output;
}



/*******************************************************************************

    Formats a string with the number of years, days, hours, minutes & seconds
    specified. The string is formatted with short names for the time periods
    (e.g. 's' instead of 'seconds').

    Params:
        s = number of seconds elapsed
        output = destination string buffer

    Returns:
        formatted string

*******************************************************************************/

public char[] formatDurationShort ( uint s, ref char[] output )
{
    output.length = 0;

    /***************************************************************************

        Appends the count of the specified value to the output string, if the
        value is > 0. Also appends a comma first, if this is not the first value
        to be appended to the output string. In this way, a comma-separated list
        of values is built up over multiple calls to this function.

        Params:
            number = value to append
            name = name of quantity

    ***************************************************************************/

    void append ( uint number, char[] name )
    {
        if ( number > 0 )
        {
            Layout!(char).print(output, "{}{}", number, name);
        }
    }

    if ( s == 0 )
    {
        output.copy("0s");
    }
    else
    {
        uint years, days, hours, minutes, seconds;
        extractTimePeriods(s, years, days, hours, minutes, seconds);

        append(years,   "y");
        append(days,    "d");
        append(hours,   "h");
        append(minutes, "m");
        append(seconds, "s");
    }

    return output;
}



/*******************************************************************************

    Works out the number of multiples of various timespans (years, days, hours,
    minutes, seconds) in the provided total count of seconds, breaking the
    seconds count down into constituent parts.

    Params:
        s = total seconds count to extract timespans from
        years = receives the extracted count of years in s
        days = receives the extracted count of days in s
        hours = receives the extracted count of hours in s
        minutes  = receives the extracted count of minutes in s
        seconds = receives the remaining seconds after all other timespans have
            been extracted from s

*******************************************************************************/

public void extractTimePeriods ( uint s, out uint years, out uint days,
    out uint hours, out uint minutes, out uint seconds )
{
    /***************************************************************************

        Works out the number of multiples of the specified timespan in the total
        count of seconds, and reduces the seconds count by these multiples. In
        this way, when this function is called multiple times with decreasingly
        large timespans, the seconds count can be broken down into constituent
        parts.

        Params:
            timespan = number of seconds in timespan to extract

        Returns:
            number of timespans in seconds

    ***************************************************************************/

    uint extract ( uint timespan )
    {
        auto extracted = seconds / timespan;
        seconds -= extracted * timespan;
        return extracted;
    }

    const minute_timespan   = 60;
    const hour_timespan     = minute_timespan * 60;
    const day_timespan      = hour_timespan * 24;
    const year_timespan     = day_timespan * 365;

    seconds = s;

    years      = extract(year_timespan);
    days       = extract(day_timespan);
    hours      = extract(hour_timespan);
    minutes    = extract(minute_timespan);
}

