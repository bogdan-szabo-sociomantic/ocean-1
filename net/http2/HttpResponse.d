module ocean.net.http2.HttpResponse;

private import ocean.net.util.ParamSet;

private import ocean.net.http2.consts.HeaderFieldNames;
private import ocean.net.http2.consts.StatusCodes: StatusCode, StatusPhrases;
private import ocean.net.http2.consts.HttpVersion: HttpVersion, HttpVersionIds;

private import ocean.core.Array: copy, concat, append;

private import tango.io.Stdout;

class HttpResponse : ParamSet
{
    private HttpVersion http_version_;
    
    private char[] data;
    
    private struct Buffers
    {
        char[] content_length;
    }
    
    private Buffers buffers;
    
    public this ( char[][] headers ... )
    {
        this(true, headers);
    }
    
    public this ( bool add_std_headers, char[][] headers ... )
    in
    {
        char[] name = HeaderFieldNames.containsColon(headers);
        
        assert (!name, "\"" ~ name ~ "\" - invalid HTTP header name (contains ':')");
    }
    body
    {
        super(add_std_headers? HeaderFieldNames.Response.NameList : [], headers);
    }
    
    public HttpVersion http_version ( HttpVersion v )
    in
    {
        assert (v <= v.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        this.http_version_ = v;
        
        return v;
    }
    
    public HttpVersion http_version ( )
    {
        return this.http_version_;
    }
    
    public char[] render ( char[] msg_body = null )
    {
        return this.render(StatusCode.init, msg_body);
    }
    
    public char[] render ( StatusCode status, char[] msg_body = null )
    in
    {
        assert (100 <= status, "invalid HTTP status code (below 100)");
        assert (status <= 999, "invalid HTTP status code (above 999)");
    }
    body
    {
        if (msg_body)
        {
            bool b = super.set("Content-Length", msg_body.length, this.buffers.content_length);
            
            assert (b);
        }
        
        this.setStatusLine(status);
        
        foreach (key, val; super) if (val)
        {
            this.data.append(key, ": ", val, "\r\n");
        }
        
        return this.data.append("\r\n", msg_body);
    }
    
    private char[] setStatusLine ( StatusCode status )
    {
        char[3] statbuf;
        
        return this.data.concat(HttpVersionIds[this.http_version_],   " ",
                                statbuf.writeUintFixed(status),        " ",
                                StatusPhrases[status],                "\r\n");
    }
}
