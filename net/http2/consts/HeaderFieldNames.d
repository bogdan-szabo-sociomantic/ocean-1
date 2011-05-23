module ocean.net.http2.consts.HeaderFieldNames;

struct HeaderFieldNames
{
    /**************************************************************************
    
        General header fields: CacheControl .. Warning
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
        
        Request header fields: Accept .. UserAgent
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3
    
     **************************************************************************/             
    
    struct Request
    {
        char[] CacheControl,        Connection,         Date,
               Pragma,              Trailer,            TransferEncoding,
               Upgrade,             Via,                Warning,
                
               Accept,              AcceptCharset,      AcceptEncoding,
               AcceptLanguage,      Authorization,      Expect,
               From,                Host,               IfMatch,
               IfModifiedSince,     IfNoneMatch,        IfRange,
               IfUnmodifiedSince,   MaxForwards,        ProxyAuthorization,
               Range,               Referer,            TE,
               UserAgent;
        
        const typeof (*this) Names =
        {
            "Cache-Control",        "Connection",       "Date",
            "Pragma",               "Trailer",          "Transfer-Encoding",
            "Upgrade",              "Via",              "Warning",
            
            "Accept",               "Accept-Charset",   "Accept-Encoding",
            "Accept-Language",      "Authorization",    "Expect",
            "From",                 "Host",             "If-Match",
            "If-Modified-Since",    "If-None-Match",    "If-Range",
            "If-Unmodified-Since",  "Max-Forwards",     "Proxy-Authorization",
            "Range",                "Referer",          "TE",
            "User-Agent"
        };
        
        mixin NameList!();
    }
    
    /**************************************************************************
    
        General header fields: CacheControl .. Warning
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
        
        Response header fields: AcceptRanges .. WwwAuthenticate
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2
    
        Entity header fields: Allow .. LastModified
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1
    
     **************************************************************************/             

    struct Response
    {
        char[] CacheControl,        Connection,         Date,
               Pragma,              Trailer,            TransferEncoding,
               Upgrade,             Via,                Warning,
               
               AcceptRanges,        Age,                ETag,
               Location,            ProxyAuthenticate,  RetryAfter,
               Server,              Vary,               WwwAuthenticate,
               
               Allow,               ContentEncoding,    ContentLanguage,
               ContentLength,       ContentLocation,    ContentMD5,
               ContentRange,        ContentType,        Expires,
               LastModified;
               
        
        const typeof (*this) Names =
        {
            "Cache-Control",        "Connection",       "Date",
            "Pragma",               "Trailer",          "Transfer-Encoding",
            "Upgrade",              "Via",              "Warning",
            
            "Accept-Ranges",        "Age",              "ETag",
            "Location",             "Proxy-Authenticate","Retry-After",
            "Server",               "Vary",             "WWW-Authenticate",
            
            "Allow",                "Content-Encoding", "Content-Language",
            "Content-Length",       "Content-Location", "Content-MD5",
            "Content-Range",        "Content-Type",     "Expires",
            "Last-Modified"
        };
        
        mixin NameList!();
    }
    
    template NameList ( )
    {
        static typeof (this.Names.tupleof)[0][(typeof (this.Names.tupleof)).length] NameList; 
        
        static this ( )
        {
            foreach (i, name; this.Names.tupleof)
            {
                assert (name.length, typeof (*this).stringof ~
                                     this.Names.tupleof[i].stringof[this.Names.stringof.length .. $] ~
                                     " is empty");
                
                this.NameList[i] = name;
            }
        }
    }
}