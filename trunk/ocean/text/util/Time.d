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

    ---

*******************************************************************************/

module ocean.text.util.Time;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.text.convert.Layout;



/*******************************************************************************

    Formats a string with the number of years, days, hours, minutes & seconds
    specified.

    Params:
        seconds = number of seconds elapsed
        output = destination string buffer

    Returns:
        formatted string

*******************************************************************************/

public char[] formatDuration ( uint seconds, ref char[] output )
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
            Layout!(char).print(output, "{} {}{}", number, name, number > 1 ? "s" : "");
            comma = true;
        }
    }

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

    auto years      = extract(year_timespan);
    auto days       = extract(day_timespan);
    auto hours      = extract(hour_timespan);
    auto minutes    = extract(minute_timespan);

    append(years,   "year");
    append(days,    "day");
    append(hours,   "hour");
    append(minutes, "minute");
    append(seconds, "second");

    return output;
}

