module ocean.net.http2.consts.HttpVersion;

enum HttpVersion : ubyte
{
    v1_1 = 1,
    v1_0 = 0
}

struct HttpVersionIds
{
    const char[][] list = 
    [
        HttpVersion.v1_1: "HTTP/1.1",
        HttpVersion.v1_0: "HTTP/1.0"
    ];
    
    static char[] opIndex ( HttpVersion ver )
    in
    {
        assert (ver <= ver.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        return this.list[ver];
    }
    
    static HttpVersion[char[]] codes;
    
    static this ( )
    {
        foreach (i, str; this.list)
        {
            this.codes[str] = cast (HttpVersion) i;
        }
    }
}