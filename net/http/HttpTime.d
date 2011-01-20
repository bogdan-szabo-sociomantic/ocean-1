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
    /**************************************************************************
    
        Date/time string destination buffer. asctime_r result length is
        guaranteed to be at most 26:
        
        http://www.opengroup.org/onlinepubs/000095399/functions/asctime_r.html
    
     **************************************************************************/
    
    private char[26] buf;
    
    /**************************************************************************
        
        Returns HTTP compliant date/time string (asctime) from UNIX time value.
        
        Params:
            t = UNIX time value to be formatted as HTTP date/time string
        
        Returns:
            HTTP date/time string from UNIX time value t. Do not modify (exposes
            an internal buffer).
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/
    
    public char[] toString ( time_t t )
    { 
        tm datetime;
        
        char* result = asctime_r(this.gmtime_safe(t, datetime), this.buf.ptr);
        
        if (!result) throw new Exception("time formatting failed");
        
        return result[0 .. strlen(result) - 1];                                 // strip tailing '\n'
    }
    
    /**************************************************************************
    
        Returns HTTP compliant date/time string (asctime) of current wall clock
        time.
        
        Returns:
            current wall clock time formatted as HTTP date/time string
        
        Throws:
            Exception if formatting failed (supposed never to happen)
        
     **************************************************************************/
    
    public char[] toString ( )
    {
        return toString(time(null));
    }
    
    /**************************************************************************
        
        Safe version of gmtime_r, checks if returned pointer is null (which
        is supposed never to happen when invoked from toString()).
        
        Params:
            t        = UNIX time value to convert to tm struct
            datetime = broken-down date/time output
        
        Returns:
            pointer to datetime
    
         Throws:
            Exception if conversion failed
        
    **************************************************************************/
    
    public static tm* gmtime_safe ( time_t t, out tm datetime )
    {
        if (!gmtime_r(&t, &datetime))
        {
            throw new Exception("time conversion failed");
        }
        
        return &datetime;
    }
}
