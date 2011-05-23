/******************************************************************************

    HTTP version identifier constants and enumerator
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.consts.HttpVersion;

/******************************************************************************

    HTTP version enumerator

 ******************************************************************************/

enum HttpVersion : ubyte
{
    Undefined = 0,
    v1_1,
    v1_0
}

/******************************************************************************

    HTTP version identifier string constants and enumerator value association

 ******************************************************************************/

struct HttpVersionIds
{
    /**************************************************************************

        HTTP version identifier string constants
        
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.1
        
     **************************************************************************/

    const char[][HttpVersion.max + 1] list = 
    [
        HttpVersion.v1_1: "HTTP/1.1",
        HttpVersion.v1_0: "HTTP/1.0"
    ];
    
    /**************************************************************************

        Obtains the HTTP identifier string by version enumerator value. ver must
        be a HttpVersion value different from HttpVersion.Undefined.
    
        Params:
            ver = HTTP version enumerator value
            
         Returns:
             HTTP version identifier string corresponding to val
             
         Throws:
             assert()s that ver is in range and not HttpVersion.Undefined.
    
     **************************************************************************/

    static char[] opIndex ( HttpVersion ver )
    in
    {
        assert (ver,            "no version id for HttpVersion.Undefined");
        assert (ver <= ver.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        return this.list[ver];
    }
    
    /**************************************************************************

        Obtains the HTTP version enumerator value by identifier string.
    
        Params:
            id = HTTP version identifier string
            
         Returns:
             Pointer to the HTTP version enumerator value corresponding to
             identifier string or null if the name identifier does not match any
             known HTTP version identifier string.
    
     **************************************************************************/

    static HttpVersion* opIn_r ( char[] id )
    {
        return id.length? id in this.codes : null;
    }
    
    /**************************************************************************

        Obtains the HTTP version enumerator value by identifier string. Does not
        throw an exception.
    
        Params:
            id = HTTP version identifier string
            
         Returns:
             HTTP version enumerator value corresponding to identifier string or
             HttpVersion.Undefined if the name string is unknown.
    
     **************************************************************************/

    static HttpVersion opIndex ( char[] id )
    {
        HttpVersion* code = opIn_r(id);
        
        return code? *code : (*code).Undefined;
    }
    
    /**************************************************************************

        HTTP version code enumerator value by name string 
    
     **************************************************************************/

    private static HttpVersion[char[]] codes;
    
    /**************************************************************************

        Static constructor; populates this.codes
    
     **************************************************************************/

    static this ( )
    {
        foreach (i, str; this.list)
        {
            this.codes[str] = cast (HttpVersion) i;
        }
        
        this.codes.rehash;
    }
}
