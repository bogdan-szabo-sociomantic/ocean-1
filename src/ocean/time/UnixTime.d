/*******************************************************************************

    Unix Epoch Time Retrieval & ISO 8601/Unixtime Parser

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        March 2010: Initial release
                    May 2010: Revised release

    Author:         David Eckardt, Thomas Nicolai

*******************************************************************************/

module ocean.time.UnixTime;

/******************************************************************************

    Imports

*******************************************************************************/

public          import      tango.stdc.time : time_t;

import      tango.stdc.time : tm, localtime, time, gmtime;

import      tango.stdc.posix.signal : timespec;

import      tango.stdc.stdio : sscanf, snprintf;

import      tango.stdc.ctype : isxdigit, tolower;

import      ocean.text.util.StringSearch;

import      tango.math.Math: max;

extern (C)
{
    protected   time_t  timegm (tm *tm);
    protected   time_t  timelocal (tm *tm);
    extern      int     daylight;
}

/******************************************************************************

    Alias declaration

    Use UnixTimeGMT for UTC time and UnixTimeLocal for local time

********************************************************************************/

alias                   UnixTime!(true)                UnixTimeGMT;
alias                   UnixTime!(false)               UnixTimeLocal;

/******************************************************************************

    Parses ISO 8601 time formated timestamp to unix time. The input time timestamp
    must accord to one of these schemes:

        "YYYY-MM-DDThh:mm:ss"
        "YYYY-MM-DDThh:mm"
        "YYYY-MM-DD"

    The 'T' between M and D stands for the 'T' character which is expected at
    that location. The number of digits of the numbers at YMDhms placeholder
    positions do not have to match the indicated value. For example,
    "1981-03-06T8:47" would be accepted although the hours value "8" has only
    one digit instead of two as indicated by "...hh..." in the scheme.

    The time stamp is parsed as far as the most comprehensive time stamp scheme
    matches; at this position parsing is stopped and the rest of the timestamp
    ignored.

    Usage example on returning unix timestamp
    ---
    UnixTimeGMT gmt;

    time_t = gmt.now;
    ---

    Note: Deprecated, use parseDateAndTime from tango.time.ISO8601 instead.

 ******************************************************************************/

deprecated struct UnixTime( bool GMT = true )
{

    static:

    /**************************************************************************

        Hex alias

     **************************************************************************/

    public alias            char[time_t.sizeof * 2]             HexTime;

    /**************************************************************************

        Return current timestamp in sec

        FIXME Please favour to use the tango Clock.now.unix.seconds() method
        in order to retrieve the gmt timestamp as it is at least 2 times
        faster. We need to investigate why!

        Returns:
            current unix time

     **************************************************************************/

    deprecated public time_t now ()
    {
        time_t t     = time(null);

        tm* datetime = GMT ? gmtime(&t) : localtime(&t);

        return timegm(datetime);
    }

    /**************************************************************************

        Converts an ISO 8601 timestamp to an Unix time value, truncating to
        integer seconds.

        A trailing null termination character is appended to timestamp and
        removed at exit.

        Params:
            timestamp = ISO 8601 input timestamp

        Returns:
            integer UNIX time value of timestamp

     **************************************************************************/

    public time_t from ( char[] timestamp )
    {
        return fromFrac(timestamp).tv_sec;
    }

    /**************************************************************************

        Converts an ISO 8601 timestamp to an Unix time value, including the
        fractional part of seconds.

        A trailing null termination character is appended to timestamp and
        removed at exit.

        Params:
            timestamp = ISO 8601 input timestamp

        Returns:
            timespec structure holding integer UNIX time value of timestamp as
            member tv_sec and fractional seconds (ns) as tv_nsec

     **************************************************************************/

    public timespec fromFrac ( char[] timestamp )
    {
        timespec ts;
        tm       datetime;
        int      n;
        char     frac_sep;

        StringSearch!().appendTerm(timestamp);

        scope (exit) StringSearch!().stripTerm(timestamp);

        n = sscanf(timestamp.ptr, "%d-%d-%dT%d:%d:%d%c%d", &datetime.tm_year,
                                                           &datetime.tm_mon,
                                                           &datetime.tm_mday,
                                                           &datetime.tm_hour,
                                                           &datetime.tm_min,
                                                           &datetime.tm_sec,
                                                           &frac_sep,
                                                           &ts.tv_nsec);

        datetime.tm_year -= 1900;
        datetime.tm_mon--;
        datetime.tm_isdst = daylight;

        ts.tv_sec = GMT ? timegm(&datetime) : timelocal(&datetime);

        auto ns = ts.tv_nsec;

        bool have_day              = n == 3,
             have_daytime          = n == 5,
             have_daytime_sec      = n == 6,
             have_daytime_sec_frac = (n == 7 || n == 8);

        if (!(have_daytime_sec_frac && StringSearch!().containsChar(".,", frac_sep)))
        {                                                                       // If no fractional seconds detected
            ts.tv_nsec = 0;                                                     // or invalid fraction separator, set
        }                                                                       // fractional seconds to 0.
        else
        {
            ts.tv_nsec = padDecDigits(ts.tv_nsec, 9);
        }

        assert ((ts.tv_sec >= 0) && (have_day || have_daytime || have_daytime_sec || have_daytime_sec_frac),
                "invalid time stamp");

        return ts;
    }

    /**************************************************************************

        Converts an ISO 8601 timestamp to an Unix time value and returns the
        hexadecimal string representation too.

        A trailing null termination character is appended to timestamp and
        removed at exit.

        Params:
            timestamp = ISO 8601 input timestamp
            hex_time  = hexadecimal timestamp output

        Returns:
            integer UNIX time value of timestamp

     ***************************************************************************/

    public time_t from ( char[] timestamp, HexTime hex_time )
    {
        return toHex(from(timestamp), hex_time);
    }

    /**************************************************************************

        Composes an integer UNIX time.

        Params:
            year,
            month,
            day,
            hour,
            minute,
            second  = time value components

        Returns:
            unix time value

     ***************************************************************************/

    public time_t from ( int year, int month = 1, int day = 1, int hour = 0,
                         int minute = 0, int second = 0 )
    {
        time_t t;

        tm datetime;

        datetime.tm_year  = year - 1900;
        datetime.tm_mon   = month - 1;
        datetime.tm_mday  = day;
        datetime.tm_hour  = hour;
        datetime.tm_min   = minute;
        datetime.tm_sec   = second;
        datetime.tm_isdst = daylight;

        t = GMT ? timegm(&datetime) : timelocal(&datetime);

        assert (t >= 0, "from: invalid date/time");

        return t;
    }

    /**************************************************************************

        Composes an integer UNIX time value and generates the hexadecimal string
        representation.

        Params:
            hex_time = output UNIX time value, hexadecimal representation
            year,
            month,
            day,
            hour,
            minute,
            second  = time value components

        Returns:
            UNIX time value

     ***************************************************************************/

    public time_t from ( HexTime hex_time, int year, int month = 1, int day = 1,
                         int hour = 0, int minute = 0, int second = 0 )
    {
        return toHex(from(year, month, day, hour, minute, second), hex_time);
    }

    /**************************************************************************

        Decomposes an integer UNIX time value.

        Params:
            time    = integer UNIX time value
            year,
            month,
            day,
            hour,
            minute,
            second  = time value components

        Returns:
            void

     ***************************************************************************/

    public void toDate ( in time_t t, out int year, out int month, out int day,
                         out int hour, out int minute, out int second )
    {
        synchronized
        {
            tm* datetime = GMT ? gmtime(&t) : localtime(&t);

            year   = datetime.tm_year + 1900;
            month  = datetime.tm_mon  + 1;
            day    = datetime.tm_mday;
            hour   = datetime.tm_hour + !!datetime.tm_isdst;
            minute = datetime.tm_min;
            second = datetime.tm_sec;
        }
    }



    /**************************************************************************

        Decomposes an integer UNIX time value which is passed as a hexadecimal
        timestamp.

        Params:
            hex_time = integer UNIX time value hexadecimal string
            year,
            month,
            day,
            hour,
            minute,
            second   = time value components

        Returns:
            void

     **************************************************************************/

    public void toDate ( in char[] hex_time, out int year, out int month,
                         out int day, out int hour, out int minute,
                         out int second )
    {
        toDate(fromHex(hex_time), year, month, day, hour, minute, second);
    }

    /**************************************************************************

        Converts a time value to a hexadecimal string.

        Params:
            time     = time value
            hex_time = hexadecimal timestamp

        Returns
            time value

     **************************************************************************/

    public time_t toHex ( time_t t, HexTime hex_time )
    {
        time_t time_bak = t;

        foreach_reverse (ref c; hex_time)
        {
            c = "0123456789abcdef"[t & 0xF];

            t >>= 4;
        }

        return time_bak;
    }

    /**************************************************************************

        Formats an ISO 8601 timestamp from timespec t.

        Params:
            timestamp = timestamp string buffer
            t         = time value

        Returns
            resulting timestamp

     **************************************************************************/

    public char[] toTimeStamp ( char[] timestamp, in timespec t )
    {
        int year, month, day, hour, minute, second;

        toDate(t.tv_sec,  year, month, day, hour, minute, second);

        return toTimeStamp(timestamp, year, month, day, hour, minute, second, t.tv_nsec);
    }

    /**************************************************************************

        Formats an ISO 8601 timestamp from the hexadecimal Unix time t.

        Params:
            timestamp = timestamp string buffer
            t         = time value

        Returns
            resulting timestamp

     **************************************************************************/

    public char[] toTimeStamp ( char[] timestamp, in HexTime t )
    {
        int year, month, day, hour, minute, second;

        toDate(t,  year, month, day, hour, minute, second);

        return toTimeStamp(timestamp, year, month, day, hour, minute, second);
    }

    /**************************************************************************

        Formats an ISO 8601 timestamp from the Unix time t.

        Params:
            timestamp = timestamp string buffer
            t         = time value

        Returns
            resulting timestamp

     **************************************************************************/

    public char[] toTimeStamp ( char[] timestamp, in time_t t )
    {
        int year, month, day, hour, minute, second;

        toDate(t,  year, month, day, hour, minute, second);

        return toTimeStamp(timestamp, year, month, day, hour, minute, second);
    }

    /**************************************************************************

        Formats an ISO 8601 timestamp from the provided time.

        Params:
            timestamp = timestamp string buffer
            year,
            month,
            day,
            hour,
            minute,
            second     = time components
            ns         = second fraction (ns)

        Returns
            resulting timestamp

     **************************************************************************/

    public char[] toTimeStamp ( char[] timestamp,
                                in int year, in int month,  in int day,
                                in int hour, in int minute, in int second,
                                in long ns = 0 )
    {
        int n = 0;

        timestamp.length  = 32;

        if (ns)
        {
            n = snprintf(timestamp.ptr, timestamp.length, "%04d-%02d-%02dT%02d:%02d:%02d.%d", year, month, day, hour, minute, second, reduceDecDigits(ns));
        }
        else
        {
            n = snprintf(timestamp.ptr, timestamp.length, "%04d-%02d-%02dT%02d:%02d:%02d", year, month, day, hour, minute, second);
        }

        timestamp.length = max(n, 0);

        return timestamp;
    }

    /**************************************************************************

        Converts a hexadecimal string into a time value.

        Params:
            hex_time = hexadecimal timestamp

        Returns
            time value

     **************************************************************************/

    public time_t fromHex ( char[] hex_time )
    {
        time_t t = 0;

        foreach (ref c; hex_time)
        {
            int d;

            t <<= 4;

            c = tolower(c);

            if ('0' <= c && c <= '9')
            {
                d = c - '0';
            }
            else if ('a' <= c && c <= 'f')
            {
                d = c - 'a' + 0xA;
            }
            else assert (false, "invalid hexadecimal digit: '" ~ c ~ '\'');

            t |=  d;
        }

        return t;
    }

    /**************************************************************************

        Tells whether str contains a hexadecimal number

        Params:
            str = input string

        Returns
            true if str contains a hexadecimal number or false otherwise

     **************************************************************************/

    public bool isHex ( char[] str )
    {
        foreach (ref c; str)
        {
            if (!isxdigit(c)) return false;
        }

        return true;
    }


    /**************************************************************************

        Returns the number of decimal digits of x.

        Params:
            x = input value

        Returns
            number of decimal digits of x

     **************************************************************************/

    private uint decDigits ( T : long ) ( T x )
    {
        uint i;

        for (i = 0; x; i++)
        {
            x /= 10;
        }

        return i;
    }

    /**************************************************************************

        Divides x by the highest power of 10 it is dividable by.

        Params:
            x = input value

        Returns
            x divided by the highest power of 10 it is dividable by

     **************************************************************************/

    private T reduceDecDigits ( T  : long ) ( T x )
    {
        while (x && !(x % 10))
        {
            x /= 10;
        }

        return x;
    }

    /**************************************************************************

        Multiplies x with a power of 10 so that the result has n decimal digits.

        Params:
            x = input value

        Returns
            x multiplied with a power of 10 so that the result has n decimal
            digits

     **************************************************************************/

    private T padDecDigits ( T : long ) ( T x, uint n )
    {
        for (uint j = decDigits(reduceDecDigits(x)); j < n; j++)
        {
            x *= 10;
        }

        return x;
    }
}

/*******************************************************************************

    Unittest

********************************************************************************/

version (UnitTest)
{
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;

    deprecated unittest
    {
        UnixTimeGMT gmt;

        // XXX: Testing local time without the proper timezone information is
        // buggy, it will break with daylight saving time
        UnixTimeLocal loc;

// deprecated
//        assert(gmt.now + 7200 == loc.now); // test 2h time shift

        char[] timestamp14 = "2010-05-25T14:00:03".dup;
        char[] timestamp16 = "2010-05-25T16:00:03".dup;

        assert(gmt.from(timestamp14) == 1274796003);
        //assert(loc.from(timestamp16) == 1274796003);

        assert(gmt.from(2010,5,25,14,0,3) == 1274796003);
        //assert(loc.from(2010,5,25,16,0,3) == 1274796003);

        UnixTimeGMT.HexTime h;
        time_t t;

        t = gmt.from(timestamp14, h);

        assert(t == 1274796003);
        assert(h == `000000004bfbd7e3`);

        t = loc.from(timestamp14, h);

        //assert(t == 1274796003);
        //assert(h == `000000004bfbd7e3`);

        int year, month, day, hour, minute, second;

        gmt.toDate(1274796003, year, month, day, hour, minute, second);

        assert(year   == 2010);
        assert(month  == 5);
        assert(day    == 25);
        assert(hour   == 14);
        assert(minute == 0);
        assert(second == 3);

        year = month = day = hour = minute = second = 0;

        loc.toDate(1274796003, year, month, day, hour, minute, second);

        // XXX: Testing local time without the proper timezone information is
        // buggy, it will break with daylight saving time
        //assert(year   == 2010);
        //assert(month  == 5);
        //assert(day    == 25);
        //assert(hour   == 16);
        //assert(minute == 0);
        //assert(second == 3);
    }
}


