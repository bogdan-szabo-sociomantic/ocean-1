module ocean.net.http2.consts.HeaderFieldNames;

private import tango.net.http.HttpConst;

private import tango.stdc.string: memchr;

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
        char[] CacheControl,
               Connection,
               Date,
               Pragma,
               Trailer,
               TransferEncoding,
               Upgrade,
               Via,
               Warning,
                
               Accept,
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
        
        const typeof (*this) Names =
        {
             HttpHeader.CacheControl.value,
             HttpHeader.Connection.value,
             HttpHeader.Date.value,
             HttpHeader.Pragma.value,
             HttpHeader.Trailer.value,
             HttpHeader.TransferEncoding.value,
             HttpHeader.Upgrade.value,
             "Via:",                                // missing in tango's HttpHeader
             HttpHeader.Warning.value,
           
             HttpHeader.Accept.value,
             HttpHeader.AcceptCharset.value,
             HttpHeader.AcceptEncoding.value,
             HttpHeader.AcceptLanguage.value,
             HttpHeader.Authorization.value,
             HttpHeader.Expect.value,
             HttpHeader.From.value,
             HttpHeader.Host.value,
             HttpHeader.IfMatch.value,
             HttpHeader.IfModifiedSince.value,
             HttpHeader.IfNoneMatch.value,
             HttpHeader.IfRange.value,
             HttpHeader.IfUnmodifiedSince.value,
             HttpHeader.MaxForwards.value,
             "Proxy-Authorization:",            // missing in tango's HttpHeader
             HttpHeader.Range.value,
             HttpHeader.Referrer.value,
             HttpHeader.TE.value,
             HttpHeader.UserAgent.value
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
        char[] CacheControl,
               Connection,
               Date,
               Pragma,
               Trailer,
               TransferEncoding,
               Upgrade,
               Via,
               Warning,
               
               AcceptRanges,
               Age,
               ETag,
               Location,
               ProxyAuthenticate,
               RetryAfter,
               Server,
               Vary,
               WwwAuthenticate,
               
               Allow,
               ContentEncoding,
               ContentLanguage,
               ContentLength,
               ContentLocation,
               ContentMD5,
               ContentRange,
               ContentType,
               Expires,
               LastModified;
               
        
        const typeof (*this) Names =
        {
            HttpHeader.CacheControl.value,
            HttpHeader.Connection.value,
            HttpHeader.Date.value,
            HttpHeader.Pragma.value,
            HttpHeader.Trailer.value,
            HttpHeader.TransferEncoding.value,
            HttpHeader.Upgrade.value,
            "Via:",                             // missing in tango's HttpHeader
            HttpHeader.Warning.value,
               
            HttpHeader.AcceptRanges.value,
            HttpHeader.Age.value,
            HttpHeader.ETag.value,
            HttpHeader.Location.value,
            HttpHeader.ProxyAuthenticate.value,
            HttpHeader.RetryAfter.value,
            HttpHeader.Server.value,
            HttpHeader.Vary.value,
            HttpHeader.WwwAuthenticate.value,
            
            HttpHeader.Allow.value,
            HttpHeader.ContentEncoding.value,
            HttpHeader.ContentLanguage.value,
            HttpHeader.ContentLength.value,
            HttpHeader.ContentLocation.value,
            "Content-MD5",                      // missing in tango's HttpHeader
            HttpHeader.ContentRange.value,
            HttpHeader.ContentType.value,
            HttpHeader.Expires.value,
            HttpHeader.LastModified.value
        };
        
        mixin NameList!();
    }
    
    template NameList ( )
    {
        static typeof (this.Names.tupleof)[0][(typeof (this.Names.tupleof)).length] NameList; 
        
        static this ( )
        out
        {
            char[] name = containsColon(this.NameList);
            
            assert (!name, "\"" ~ name ~ "\" - invalid HTTP header name (contains ':')");
        }
        body
        {
            alias typeof (this.Names.tupleof)[0] T;
            
            foreach (i, name; this.Names.tupleof)
            {
                static assert (is (typeof (name) == T));
                
                this.NameList[i] = stripTailingColon(name);
            }
        }
    }
    
    /**************************************************************************

        Scans key for ':'.
        
        Params:
            key = key to scan for ':'
            
        Returns:
            true if key contains ':' or false otherwise
        
     **************************************************************************/

    public static char[] containsColon ( char[][] names ... )
    {
        foreach (name; names)
        {
            if (memchr(name.ptr, ':', name.length))
            {
                return name;
            }
        }
        
        return null;
    }
    
    /**************************************************************************

        Strips the tailing ':' from key if present. This is the only place where
        a ':' may appear in key.
        
        Params:
            key = key to strip tailing ':'
            
        Returns:
            result (slices key)
        
     **************************************************************************/
    
    private static char[] stripTailingColon ( char[] key )
    {
        return key.length? key[0 .. $ - (key[$ - 1] == ':')] : key;
    }
}