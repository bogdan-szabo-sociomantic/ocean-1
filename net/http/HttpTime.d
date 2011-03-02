/******************************************************************************

    Formats an UNIX time value to a HTTP compliant date/time string
    
    Copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    Version:        Jan 2011: Initial release
    
    Authors:        David Eckardt
    
 ******************************************************************************/

module ocean.net.http.HttpTime;

/******************************************************************************

    Imports 

 ******************************************************************************/

private     import      tango.stdc.time:       time_t, tm, time;
private     import      tango.stdc.posix.time: gmtime_r, asctime_r;
private     import      tango.stdc.string:     strlen;

/******************************************************************************

    Formats an UNIX time value to a HTTP compliant (asctime) date/time string.
    Contains a static length array as string buffer to provide
    memory-friendliness.
    
 ******************************************************************************/

struct HttpTime
{
    public const size_t MaxResultLength = 26;
    
    /**************************************************************************
    
        Date/time string destination buffer. asctime_r result length is
        guaranteed to be at most 26:
        
        http://www.opengroup.org/onlinepubs/000095399/functions/asctime_r.html
    
     **************************************************************************/
    
    private char[this.MaxResultLength] buf;
    
    /**************************************************************************
        
        Generates a HTTP compliant date/time string (asctime) from t or the
        current wall clock time.
        
        Params:
            t = UNIX time value to be formatted as HTTP date/time string
                (optional, omit to use the current wall clock time)
        
        Returns:
            HTTP date/time string from UNIX time value t. Do not modify (exposes
            an internal buffer).
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/
    
    public char[] opCall ( time_t t )
    { 
        return this.format(this.buf, t);
    }
    
    public char[] opCall ( )
    {
        return this.format(this.buf);
    }
    
    /**************************************************************************
    
        Generates a HTTP compliant date/time string (asctime) from t or the
        current wall clock time.
        
        Params:
            dst = destination string
            t   = UNIX time value to be formatted as HTTP date/time string
                  (optional, omit to use the current wall clock time)
        
        Returns:
            dst
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/

    public static char[] opCall ( ref char[] dst, time_t t )
    { 
        if (dst.length < this.MaxResultLength)
        {
            dst.length = this.MaxResultLength;
        }
        
        dst.length = format(dst, t).length;
        
        return dst;
    }
    
    public static char[] opCall ( char[] dst )
    {
        return opCall(dst, time(null));
    }
    
    /**************************************************************************
    
        Generates a HTTP compliant date/time string (asctime) from t or the
        current wall clock time and appends it to dst.
        
        Params:
            dst = destination string
            t   = UNIX time value to be formatted as HTTP date/time string
                  (optional, omit to use the current wall clock time)
        
        Returns:
            dst
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/
    
    public static char[] append ( ref char[] dst, time_t t )
    {
        size_t len = dst.length;
        
        dst.length = len + this.MaxResultLength;
        
        dst.length = format(dst[len .. $], t).length + len;
        
        return dst;
    }

    public static char[] append ( ref char[] dst )
    {
        return append(dst, time(null));
    }
    
    /**************************************************************************
    
        Generates a HTTP compliant date/time string (asctime) from t or the
        current wall clock time.
        
        Notes: dst.length must be at least 26. A slice to the valid data in dst,
        starting from dst[0], is returned. dst.length is not changed so dst will
        contain tailing garbage.
        
        Params:
            dst = destination string
            t   = UNIX time value to be formatted as HTTP date/time string
                  (optional, omit to use the current wall clock time)
        
        Returns:
            slice to valid result data in dst, starting at dst[0]
    
         Throws:
            Exception if formatting failed (supposed never to happen)
        
    **************************************************************************/

    public static char[] format ( char[] dst, time_t t )
    in
    {
        assert (dst.length >= this.MaxResultLength);
    }
    out (result)
    {
        assert (dst.ptr is result.ptr);
    }
    body
    {
        tm datetime;
        
        if (!gmtime_r(&t, &datetime))
        {
            throw new Exception("time conversion failed");
        }
        
        char* result = asctime_r(&datetime, dst.ptr);
        
        if (!result) throw new Exception("time formatting failed");
        
        size_t len = strlen(result);
        
        assert (len);
        
        return dst[0 .. len - 1];                                               // strip tailing '\n'
    }
    
    public static char[] format ( char[] dst )
    {
        return format(dst, time(null));
    }
}
