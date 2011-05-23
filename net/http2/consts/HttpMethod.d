/******************************************************************************

    HTTP method name constants and enumerator
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
    TODO: add support for extension methods (when needed)
    
 ******************************************************************************/

module ocean.net.http2.consts.HttpMethod;

/******************************************************************************

    HTTP method enumerator

 ******************************************************************************/

enum HttpMethod : ubyte
{
    Undefined = 0,
    Get,
    Head,
    Post,
    Put,
    Delete,
    Trace,
    Connect,
    Options
}

/******************************************************************************

    HTTP method name string constants and enumerator value association

 ******************************************************************************/

struct HttpMethodNames
{
    /**************************************************************************

        HTTP method name string constants
        
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.1
        
     **************************************************************************/

    const char[][HttpMethod.max + 1] List =
    [
        HttpMethod.Undefined:  "",
        HttpMethod.Get:        "GET",
        HttpMethod.Head:       "HEAD",
        HttpMethod.Post:       "POST",
        HttpMethod.Put:        "PUT",
        HttpMethod.Delete:     "DELETE",
        HttpMethod.Trace:      "TRACE",
        HttpMethod.Connect:    "CONNECT",
        HttpMethod.Options:    "OPTIONS"
    ];
    
    /**************************************************************************

        HTTP method enumerator value by name string 
    
     **************************************************************************/

    private static HttpMethod[char[]] methods_by_name;
    
    /**************************************************************************

        Obtains the HTTP method enumerator value by name string. Does not throw
        an exception.
    
        Params:
            name = HTTP method name string
            
         Returns:
             HTTP method enumerator value corresponding to name string or
             HttpMethod.Undefined if the name string is unknown.
    
     **************************************************************************/

    static HttpMethod opIndex ( char[] name )
    {
        HttpMethod* method = name? name in this.methods_by_name : null;
        
        return method? *method : HttpMethod.init;
    }
    
    /**************************************************************************

        Obtains the HTTP method name string by enumerator value. Does not throw
        an exception.
    
        Params:
            method = HTTP method enumerator value
            
         Returns:
             HTTP method name string corresponding to name method or null on
             invalid value.
    
     **************************************************************************/

    static char[] opIndex ( HttpMethod method )
    {
        return (method <= method.max)? this.List[method] : null;
    }
    
    /**************************************************************************

        Static constructor; populates the association map
    
     **************************************************************************/

    static this ( )
    {
        foreach (method, name; this.List)
        {
            this.methods_by_name[name] = cast (HttpMethod) method;
        }
        
        this.methods_by_name.rehash;
    }
}
