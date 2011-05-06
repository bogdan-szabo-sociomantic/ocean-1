module ocean.net.http2.Headers;

private import ocean.net.http2.IndexStructFields;

struct Headers
{
    struct General
    {
        char[] CacheControl,
               Connection,
               Date,
               Pragma,
               Trailer,
               TransferEncoding,
               Upgrade,
               Via,
               Warning;
            
        private static const char[][] ids =
        [
             "Cache-Control",
             "Connection",
             "Date",
             "Pragma",
             "Trailer",
             "Transfer-Encoding",
             "Upgrade",
             "Via",
             "Warning"
        ];
    }
    
    struct Request
    {
        char[] Accept,
               AcceptCharset,
               AcceptEncoding,
               AcceptLanguage,
               Authorization,
               Expect,
               From,
               Host,
               IfMatch,
               IfModifiedSince,
               IfNoneMatch,
               IfRange,
               IfUnmodifiedSince,
               MaxForwards,
               ProxyAuthorization,
               Range,
               Referer,
               TE,
               UserAgent;
        
        private static const char[][] ids =
        [
            "Accept",
            "Accept-Charset",
            "Accept-Encoding",
            "Accept-Language",
            "Authorization",
            "Expect",
            "From",
            "Host",
            "If-Match",
            "If-Modified-Since",
            "If-None-Match",
            "If-Range",
            "If-Unmodified-Since",
            "Max-Forwards",
            "Proxy-Authorization",
            "Range",
            "Referer",
            "TE",
            "User-Agent"
        ];
    }
    
    struct Element
    {
        char[] key, val;
    }
    
    char[] Method, Uri, Version;
    
    General general;
    Request request;
    
    char[][char[]] expected;
    
    Element[] unexpected;
    
    bool set ( char[] key, char[] val )
    {
        char[]* dest = key in *this;
        
        bool expected = dest !is null;
        
        if (expected)
        {
            *dest = val;
        }
        else
        {
            this.unexpected ~= Element(key, val);
        }
        
        return expected;
    }
    
    private static size_t[char[]] field_offsets;
    
    static this ( )
    {
        typeof (*this) instance;
        
        foreach (i, field; instance.tupleof) static if (is (typeof (field) == struct))
        {
            const ids = field.ids;
            
            const offset = instance.tupleof[i].offsetof;
            
            foreach (j, T; typeof (field.tupleof))
            {
                this.field_offsets[ids[j]] = field.tupleof[j].offsetof + offset;
            }
        }
    }
    
    char[]* opIn_r ( char[] key )
    {
        size_t* field_offset = key in this.field_offsets;
        
        return field_offset? this.getField(*field_offset) : key in this.expected;
    }
    
    char[] opIndexAssign ( char[] value, char[] id )
    {
        return *this.getField(this.field_offsets[id]) = value;
    }
    
    typeof (this) reset ( )
    {
        foreach (ref str; [this.Method, this.Uri, this.Version])
        {
            str = null;
        }
        
        this.general = this.general.init;
        this.request = this.request.init;
        
        foreach (key, ref val; this.expected)
        {
            val = null;
        }
        
        this.unexpected.length = 0;
        
        return this;
    }
    
    private char[]* getField ( size_t offset )
    in
    {
        assert (offset < (*this).sizeof);
    }
    body
    {
        return cast (char[]*) ((cast (void*) this) + offset);
    }
}
