/******************************************************************************

    Formats an UNIX time value to a HTTP compliant date/time string
    
    Copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    Version:        Jan 2011: Initial release
    
    Authors:        David Eckardt
    
    Formats an UNIX time value to a HTTP compliant (RFC 1123) date/time string.
    Contains a static length array as string buffer to provide
    memory-friendliness.
    
 ******************************************************************************/

module ocean.net.http2.time.HttpTimeFormatter;

/******************************************************************************

    Imports 

 ******************************************************************************/

private import tango.stdc.time:       time_t, tm, time;
private import tango.stdc.posix.time: gmtime_r, localtime_r;
private import tango.stdc.stdlib:     div;

/******************************************************************************/

struct HttpTimeFormatter
{
    /**************************************************************************
    
        Date/time string length constant
    
     **************************************************************************/

    public const size_t ResultLength = "Sun, 06 Nov 1994 08:49:37 GMT".length;
    
    /**************************************************************************
    
        Date/time string destination buffer
        
        http://www.opengroup.org/onlinepubs/000095399/functions/asctime_r.html
    
     **************************************************************************/
    
    private char[this.ResultLength] buf;
    
    /**************************************************************************
    
        Weekday/month name constants
    
     **************************************************************************/

    private const char[3][7]  weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    private const char[3][12] months   = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    
    /**************************************************************************
        
        Generates a HTTP compliant date/time string (asctime) from t.
        
        Params:
            t = UNIX time value to be formatted as HTTP date/time string
        
        Returns:
            HTTP date/time string from UNIX time value t. Do not modify (exposes
            an internal buffer).
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/
    
    public char[] format ( time_t t )
    { 
        return this.format(this.buf, t);
    }
    
    /**************************************************************************
    
        Ditto; uses the current wall clock time.
        
        Returns:
            HTTP date/time string from UNIX time value t. Do not modify (exposes
            an internal buffer).
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/

    public char[] format ( )
    {
        return this.format(this.buf);
    }
    
    /**************************************************************************
    
        Generates a HTTP compliant date/time string from t and stores it in dst.
        dst.length must be ResultLength.
        
        Params:
            dst      = destination string
            t        = UNIX time value to be formatted as HTTP date/time string
            is_local = true: t is 
        
        Returns:
            slice to valid result data in dst, starting at dst[0]
    
         Throws:
            Exception if formatting failed (supposed never to happen)
        
    **************************************************************************/
    
    public static char[] format ( char[] dst, time_t t )
    in
    {
        assert (dst.length == this.ResultLength);
    }
    body
    {
        tm  datetime;
        
        tm* datetimep = gmtime_r(&t, &datetime);
        
        if (datetimep is null) throw new Exception("time conversion failed");
        
        with (*datetimep)
        {
            dst[ 0 ..  3] = this.weekdays[tm_wday];
            dst[ 3 ..  5] = ", ";
            dst[ 5 ..  7].fmt(tm_mday);
            dst[ 7      ] = ' ';
            dst[ 8 .. 11] = this.months[tm_mon];
            dst[11      ] = ' ';
            dst[12 .. 16].fmt(tm_year + 1900);
            dst[16      ] = ' ';
            dst[17 .. 19].fmt(tm_hour);
            dst[19      ] = ':';
            dst[20 .. 22].fmt(tm_min);
            dst[22      ] = ':';
            dst[23 .. 25].fmt(tm_sec);
        }
        
        dst[$ - " GMT".length .. $] = " GMT";
        
        return dst;
    }
    
    /**************************************************************************
    
        Ditto; uses the current wall clock time.
        
        Params:
            dst = destination string
        
        Returns:
            slice to valid result data in dst, starting at dst[0]
    
         Throws:
            Exception if formatting failed (supposed never to happen)
        
    **************************************************************************/

    public static char[] format ( char[] dst )
    {
        return format(dst, time(null));
    }
    
    /**************************************************************************
    
        Converts n to a decimal string, left-padding with '0'.
        n must be at least 0 and fit into dst (be less than 10 ^ dst.length).
        
        Params:
            dst = destination string
            n   = number to convert
            
    **************************************************************************/

    private static void fmt ( char[] dst, int n )
    in
    {
       assert (n >= 0); 
    }
    out
    {
        assert (!n, "decimal formatting overflow");
    }
    body
    {
        foreach_reverse (ref c; dst) with (div(n, 10))
        {
            c = rem + '0';
            n = quot;
        }
    }
    
    /**************************************************************************/
    
    unittest
    {
        char[this.ResultLength] buf;
        assert (format(buf, 352716457) == "Fri, 06 Mar 1981 08:47:37 GMT");
    }
}
