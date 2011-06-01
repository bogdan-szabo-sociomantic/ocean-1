/******************************************************************************

    HTTP header field name constants
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
 ******************************************************************************/

module ocean.net.http2.consts.HeaderFieldNames;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.http2.consts.util.NameList;

/******************************************************************************/

struct HeaderFieldNames
{
    /**************************************************************************
    
        General header fields for request and response
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4.5
    
     **************************************************************************/             
    
    struct General
    {
        /**********************************************************************
        
            Field name members
        
         **********************************************************************/             
        
        char[] CacheControl,        Connection,         Date,
               Pragma,              Trailer,            TransferEncoding,
               Upgrade,             Via,                Warning;
        
        /**********************************************************************
        
            Constant instance holding field names
        
         **********************************************************************/             
        
        const typeof (*this) Names =
        {
            "Cache-Control",        "Connection",       "Date",
            "Pragma",               "Trailer",          "Transfer-Encoding",
            "Upgrade",              "Via",              "Warning"
        };
        
        /**********************************************************************
        
            Adds static char[][n] NameList, a list of the name constants
        
         **********************************************************************/             
        
        mixin NameList!();
    }

    /**************************************************************************
        
        Request specific header fields in addition to the Genereal fields
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.3

     **************************************************************************/             
    
    struct Request
    {
        /**********************************************************************
        
            Field name members
        
         **********************************************************************/             
        
        char[] Accept,              AcceptCharset,      AcceptEncoding,
               AcceptLanguage,      Authorization,      Expect,
               From,                Host,               IfMatch,
               IfModifiedSince,     IfNoneMatch,        IfRange,
               IfUnmodifiedSince,   MaxForwards,        ProxyAuthorization,
               Range,               Referer,            TE,
               UserAgent;
        
        /**********************************************************************
        
            Constant instance holding field names
        
         **********************************************************************/             
        
        const typeof (*this) Names =
        {
            "Accept",               "Accept-Charset",   "Accept-Encoding",
            "Accept-Language",      "Authorization",    "Expect",
            "From",                 "Host",             "If-Match",
            "If-Modified-Since",    "If-None-Match",    "If-Range",
            "If-Unmodified-Since",  "Max-Forwards",     "Proxy-Authorization",
            "Range",                "Referer",          "TE",
            "User-Agent"
        };
        
        /**********************************************************************
        
            Adds static char[][n] NameList, a list of the name constants
        
         **********************************************************************/             
        
        mixin NameList!();
    }
    
    /**************************************************************************
    
        Response specific header fields in addition to the Genereal fields
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.2
    
     **************************************************************************/             

    struct Response
    {
        /**********************************************************************
        
            Field name members
        
         **********************************************************************/             
        
        char[] AcceptRanges,        Age,                ETag,
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
    
        Entity header fields for requests/responses which support entities.
        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec7.html#sec7.1
    
     **************************************************************************/             
    
    struct Entity
    {
        /**********************************************************************
        
            Field name members
        
         **********************************************************************/             
        
        char[] Allow,               ContentEncoding,    ContentLanguage,
               ContentLength,       ContentLocation,    ContentMD5,
               ContentRange,        ContentType,        Expires,
               LastModified;
        
        /**********************************************************************
        
            Constant instance holding field names
        
         **********************************************************************/             
        
        const typeof (*this) Names =
        {
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
}