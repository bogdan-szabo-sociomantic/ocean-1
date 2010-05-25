/*******************************************************************************
    
    Converts between time stamp and Unix time value 

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    author:         David Eckardt
    
*******************************************************************************/

module core.util.UnixTime;

/******************************************************************************

    Imports

*******************************************************************************/

private         import      tango.stdc.time: tm, mktime, localtime, gmtime;

private         import      tango.stdc.time: time_t;

private         import      tango.stdc.stdio: sscanf;

private         import      tango.stdc.ctype:    isxdigit, tolower;

private         import      ocean.text.util.StringSearch;

/******************************************************************************

    UnixTime structure
    
    Converts between a time stamp and an Unix time value.
    The beginning of the time stamp must accord to one of these schemes:

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
    
*******************************************************************************/

struct UnixTime
{
    static:
    
    alias char[time_t.sizeof * 2] HexTime;
    
    bool convert_to_gmt = true;
    
    /**************************************************************************
    
        Converts timestamp to an integer UNIX time value.
        
        A trailing null termination character is appended to timestamp and
        removed at exit.
        
        Params:
            timestamp = input time stamp
            
        Returns:
            integer UNIX time value of timestamp
    
     **************************************************************************/
    
    time_t fromTimeStamp ( char[] timestamp )
    {
        tm     datetime;
        time_t t;
        int    n;
        
        StringSearch!().appendTerm(timestamp);
        
        scope (exit) StringSearch!().stripTerm(timestamp);
        
        n = sscanf(timestamp.ptr, "%d-%d-%dT%d:%d:%d", &datetime.tm_year,
                                                       &datetime.tm_mon,
                                                       &datetime.tm_mday,
                                                       &datetime.tm_hour,
                                                       &datetime.tm_min,
                                                       &datetime.tm_sec);
        datetime.tm_year -= 1900;
        datetime.tm_mon--;
        
        t = mktime(&datetime);
        
        assert (((n == 6) || (n == 5) || (n == 3)) && (t >= 0), "invalid time stamp");
        
        return t;
    }
    
    /**************************************************************************
    
        Converts timestamp to an integer UNIX time value and generates the
        hexadecimal string representation.
        
        A trailing null termination character is appended to timestamp and
        removed at exit.
        
        Params:
            timestamp = input time stamp
            hex_time  = hexadecimal string representation output
            
        Returns:
            integer UNIX time value of timestamp
    
     **************************************************************************/

    time_t fromTimeStamp ( char[] timestamp, HexTime hex_time )
    {
        return toHex(fromTimeStamp(timestamp), hex_time);
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
    
     **************************************************************************/
    
    void toDateTime ( time_t t, out int year, out int month, out int day,
                                out int hour, out int minute, out int second )
    {
        synchronized
        {
            tm* datetime = this.convert_to_gmt? gmtime(&t) : localtime(&t);
            
            year   = datetime.tm_year + 1900;
            month  = datetime.tm_mon  + 1;
            day    = datetime.tm_mday;
            hour   = datetime.tm_hour;
            minute = datetime.tm_min;
            second = datetime.tm_sec;
        }
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
            UNIX time value
        
     **************************************************************************/
    
    time_t fromDateTime ( int year, int month = 1, int day = 1, int hour = 0, 
                          int minute = 0, int second = 0 )
    {
        time_t result;
        
        tm datetime;
        
        datetime.tm_year = year - 1900;
        datetime.tm_mon  = month - 1;
        datetime.tm_mday = day;
        datetime.tm_hour = hour;
        datetime.tm_min  = minute;
        datetime.tm_sec  = second;
        
        result = mktime(&datetime);
        
        assert (result >= 0, "fromDateTime: invalid date/time");
        
        return result;
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
    
     **************************************************************************/

    time_t fromDateTime ( HexTime hex_time, int year, int month = 1, 
                                            int day = 1, int hour = 0,
                                            int minute = 0, int second = 0 )
    {
        return toHex(fromDateTime(year, month, day, hour, minute, second), hex_time);
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
    
     **************************************************************************/
    
    void toDateTime ( char[] hex_time, out int year, out int month, out int day,
                                       out int hour, out int minute, out int second )
    {
        toDateTime(fromHex(hex_time), year, month, day, hour, minute, second);
    }
    
    /**************************************************************************
    
        Converts a time value to a hexadecimal string.
        
        Params:
            time     = time value
            hex_time = hexadecimal string
        
        Returns
            time value
        
     **************************************************************************/
    
    time_t toHex ( time_t t, HexTime hex_time )
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

    time_t fromHex ( char[] hex_time )
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

    bool isHex ( char[] str )
    {
        foreach (ref c; str)
        {
            if (!isxdigit(c)) return false;
        }
        
        return true;
    }
}

