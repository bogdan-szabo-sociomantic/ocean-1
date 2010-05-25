/*******************************************************************************
    
    Unix Epoch Time Retrieval & ISO 8601/Unixtime Parser

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        March 2010: Initial release
                    May 2010: Revised release
                    
    Author:         David Eckardt, Thomas Nicolai
    
*******************************************************************************/

module core.util.UnixTime;

/******************************************************************************

    Imports

*******************************************************************************/

private         import      tango.stdc.time : tm, localtime, time, gmtime, time_t;
 
private         import      tango.stdc.stdio : sscanf;

private         import      tango.stdc.ctype : isxdigit, tolower;

private         import      ocean.text.util.StringSearch;

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

    Parses ISO 8601 time formated string to unix time. The input time string 
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
    matches; at this position parsing is stopped and the rest of the string
    ignored.
    
    Usage example on returning unix timestamp
    ---
    UnixTimeGMT gmt;
    
    time_t = gmt.now;
    ---
    
********************************************************************************/

template UnixTime( bool GMT = true ) { struct UnixTime
{

    static:
    
    /**************************************************************************
        
        Hex alias
    
     **************************************************************************/

    public alias            char[time_t.sizeof * 2]             HexTime;
    
    /**************************************************************************
        
        Return current timestamp in sec
        
        Returns:
            current unix time
    
     ***************************************************************************/
    
    public time_t now ()
    {
        time_t t     = time(null);
        
        tm* datetime = GMT ? gmtime(&t) : localtime(&t);
        
        return timegm(datetime);
    }
    
    /**************************************************************************
    
        Converts ISO 8601 timestamp to unix timestamp
        
        A trailing null termination character is appended to timestamp and
        removed at exit.
        
        Params:
            string = ISO 8601 input string
            
        Returns:
            integer UNIX time value of timestamp
    
     ***************************************************************************/
    
    public time_t from ( in char[] string )
    {
        tm     datetime;
        time_t t;
        int    n;
        
        StringSearch!().appendTerm(string);
        
        scope (exit) StringSearch!().stripTerm(string);
        
        n = sscanf(string.ptr, "%d-%d-%dT%d:%d:%d", &datetime.tm_year,
                                                    &datetime.tm_mon,
                                                    &datetime.tm_mday,
                                                    &datetime.tm_hour,
                                                    &datetime.tm_min,
                                                    &datetime.tm_sec);
        datetime.tm_year -= 1900;
        datetime.tm_mon--;
        datetime.tm_isdst = daylight;
        
        t = GMT ? timegm(&datetime) : timelocal(&datetime);
        
        assert (((n == 6) || (n == 5) || (n == 3)) && (t >= 0), "invalid time stamp");
        
        return t;
    }
    
    /**************************************************************************
    
        Converts ISO 8601 timestamp to unix timestamp and returns the 
        hexadecimal string representation too.
        
        A trailing null termination character is appended to timestamp and
        removed at exit.
        
        Params:
            timestamp = ISO 8601 input string
            hex_time  = hexadecimal string output
            
        Returns:
            integer UNIX time value of timestamp
    
     ***************************************************************************/

    public time_t from ( in char[] string, HexTime hex_time )
    {
        return toHex(from(string), hex_time);
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
            hour   = datetime.tm_hour;
            minute = datetime.tm_min;
            second = datetime.tm_sec;
        }
    }
    

    
    /**************************************************************************
    
        Decomposes an integer UNIX time value which is passed as a hexadecimal
        string.
        
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
            hex_time = hexadecimal string
        
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
    
        Converts a hexadecimal string into a time value.
        
        Params:
            hex_time = hexadecimal string
        
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
    
}}

/*******************************************************************************

    Unittest

********************************************************************************/

debug (OceanUnitTest)
{
    import tango.util.log.Trace;
    import tango.core.Memory;
    import tango.time.StopWatch;
    import tango.core.Thread;
    
    unittest
    {
        Trace.formatln("Running ocean.time.Time unittest");
        
        UnixTimeGMT gmt;
        UnixTimeLocal loc;
        
        assert(gmt.now + 7200 == loc.now); // test 2h time shift

        assert(gmt.from("2010-05-25T14:00:03") == 1274796003);
        assert(loc.from("2010-05-25T16:00:03") == 1274796003);
        
        assert(gmt.from(2010,5,25,14,0,3) == 1274796003);
        assert(loc.from(2010,5,25,16,0,3) == 1274796003);
        
        UnixTimeGMT.HexTime h;
        time_t t;
        
        t = gmt.from("2010-05-25T14:00:03", h);
        
        assert(t == 1274796003);
        assert(h == `4bfbd7e3`);
        
        t = loc.from("2010-05-25T16:00:03", h);
        
        assert(t == 1274796003);
        assert(h == `4bfbd7e3`);
        
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
        
        assert(year   == 2010);
        assert(month  == 5);
        assert(day    == 25);
        assert(hour   == 16);
        assert(minute == 0);
        assert(second == 3);
        
        Trace.formatln("done unittest");
    }
}


