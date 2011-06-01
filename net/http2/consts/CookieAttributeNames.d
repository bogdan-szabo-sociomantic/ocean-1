/******************************************************************************

    HTTP session "cookie" attribute name constants as defined in RFC 2109
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
    @see http://www.w3.org/Protocols/rfc2109/rfc2109.txt
    
    Note: CookieAttributeNames contains the "expires" instead of the "max-age"
    cookie attribute name as defined in RFC 2109. The reason is that,
    unfortunately, the cross-browser compatibility of "expires" is much better
    than of "max-age".
    
 ******************************************************************************/

module net.http2.consts.CookieAttributeNames;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.http2.consts.util.NameList;

/******************************************************************************/

struct CookieAttributeNames
{
    char[] Comment, Domain,
           Expires,
           Path, Secure, Version;
    
    const typeof (*this) Names =
    {
         "comment", "domain", "expires", "path", "secure", "version"
    };
    
    mixin NameList!();
}
