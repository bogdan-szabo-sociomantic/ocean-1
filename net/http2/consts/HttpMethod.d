module ocean.net.http2.consts.HttpMethod;

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

struct HttpMethodNames
{
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
    
    private static HttpMethod[char[]] methods_by_name;
    
    static HttpMethod opIndex ( char[] name )
    {
        HttpMethod* method = name? name in this.methods_by_name : null;
        
        return method? *method : HttpMethod.init;
    }
    
    static char[] opIndex ( HttpMethod method )
    {
        return (method <= method.max)? this.List[method] : null;
    }
    
    static this ( )
    {
        foreach (method, name; this.List)
        {
            this.methods_by_name[name] = cast (HttpMethod) method;
        }
    }
}
