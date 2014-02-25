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

module ocean.net.http.consts.CookieAttributeNames;

/******************************************************************************/

struct CookieAttributeNames
{
    char[] Comment, Domain,
           Expires,
           Path, Secure, Version;

    alias .CookieAttributeNameStrings   Names;
    alias .CookieAttributeNameList      NameList;
}

const CookieAttributeNames CookieAttributeNameStrings =
{
    Comment: "comment",
    Domain:  "domain",
    Expires: "expires",
    Path:    "path",
    Secure:  "secure",
    Version: "version"
};

const char[][] CookieAttributeNameList;

private char[][CookieAttributeNames.tupleof.length] CookieAttributeNameList_;

static this ( )
{
    foreach (i, name; CookieAttributeNameStrings.tupleof)
    {
        CookieAttributeNameList_[i] = name;
    }

    CookieAttributeNameList = CookieAttributeNameList_;
}

/******************************************************************************/

unittest
{
    static assert(CookieAttributeNames.Names.Comment == "comment");
    static assert(CookieAttributeNames.Names.Domain  == "domain");
    static assert(CookieAttributeNames.Names.Expires == "expires");
    static assert(CookieAttributeNames.Names.Path    == "path");
    static assert(CookieAttributeNames.Names.Secure  == "secure");
    static assert(CookieAttributeNames.Names.Version == "version");

    foreach (i, attribute_name; CookieAttributeNames.Names.tupleof)
    {
        assert(CookieAttributeNameList[i] == attribute_name,
               "mismatch of CookieAttributeNameList[" ~ i.stringof ~ ']');
    }
}
