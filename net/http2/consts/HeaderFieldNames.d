/******************************************************************************

    HTTP header field name constants
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.consts.HeaderFieldNames;

/******************************************************************************/

struct HeaderFieldNames
{
    /**************************************************************************
        
        According to the HTTP request message header definition
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5
        the standard request header fields are:
        
            General header fields: CacheControl .. Warning
            @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
            
            Request header fields: Accept .. UserAgent
            @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3
            
            Entity header fields: Allow .. LastModified
            @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1

     **************************************************************************/             
    
    struct Request
    {
        /**********************************************************************
        
            Field name members
        
         **********************************************************************/             
        
        char[] CacheControl,        Connection,         Date,
               Pragma,              Trailer,            TransferEncoding,
               Upgrade,             Via,                Warning,
                
               Accept,              AcceptCharset,      AcceptEncoding,
               AcceptLanguage,      Authorization,      Expect,
               From,                Host,               IfMatch,
               IfModifiedSince,     IfNoneMatch,        IfRange,
               IfUnmodifiedSince,   MaxForwards,        ProxyAuthorization,
               Range,               Referer,            TE,
               UserAgent,
               
               Allow,               ContentEncoding,    ContentLanguage,
               ContentLength,       ContentLocation,    ContentMD5,
               ContentRange,        ContentType,        Expires,
               LastModified;
        
        /**********************************************************************
        
            Constant instance holding field names
        
         **********************************************************************/             
        
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
            "User-Agent",
            
            "Allow",                "Content-Encoding", "Content-Language",
            "Content-Length",       "Content-Location", "Content-MD5",
            "Content-Range",        "Content-Type",     "Expires",
            "Last-Modified"
        };
        
        /**********************************************************************
        
            Adds static char[][n] NameList, a list of the name constants
        
         **********************************************************************/             
        
        mixin NameList!();
    }
    
    /**************************************************************************
    
        According to the HTTP response message header definition
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html
        the standard request header fields are: 
        
        General header fields: CacheControl .. Warning
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
        
        Response header fields: AcceptRanges .. WwwAuthenticate
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2
    
        Entity header fields: Allow .. LastModified
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1
    
     **************************************************************************/             

    struct Response
    {
        /**********************************************************************
        
            Field name members
        
         **********************************************************************/             
        
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
               
        
        /**********************************************************************
        
            Constant instance holding field names
        
         **********************************************************************/             
        
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
        
        /**********************************************************************
        
            Adds static char[][n] NameList, a list of the name constants
        
         **********************************************************************/             
        
        mixin NameList!();
    }
    
    /**************************************************************************
    
        NameList template to be mixed in into Request/Response
    
     **************************************************************************/             

    template NameList ( )
    {
        /**********************************************************************
        
            NameList member
        
         **********************************************************************/             

        static typeof (this.Names.tupleof)[0][(typeof (this.Names.tupleof)).length] NameList; 
        
        /**********************************************************************
        
            Static constructor; populates NameList
        
         **********************************************************************/             

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