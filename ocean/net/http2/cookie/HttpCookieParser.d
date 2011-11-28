/*******************************************************************************

    Http Session "Cookie" Structure 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Apr 2010: Initial release

    author:         David Eckardt
    
    Reference:      RFC 2109
    
                    @see http://www.w3.org/Protocols/rfc2109/rfc2109.txt
                    @see http://www.servlets.com/rfcs/rfc2109.html
    
 ******************************************************************************/

module ocean.net.http2.cookie.HttpCookieParser;

/******************************************************************************
 
    Imports
 
 ******************************************************************************/

private import ocean.net.util.QueryParams: QueryParamSet;

/******************************************************************************/

class HttpCookieParser : QueryParamSet
{
    this ( char[][] attribute_names ... )
    {
        super(';', '=', attribute_names);
    }
}

/******************************************************************************/

unittest
{
    const char[] cookie = "_codespaces_hosted_edition_session = BAh7BzoMdXNlcl9pZGkCXC46D3Nlc3Npb25faWQiJTY2NTQ0OWM0N2Q2NjlkZDY1OTY2MGYwZDY5MmYwY2M0--c5e3812e263d129b476cf498f369a07ecf822e86; path=/; HttpOnly";
    
    const char[][] attribute_names =
    [
        "_codespaces_hosted_edition_session",
        "path",
        "HttpOnly"
    ];
    
    scope cp = new HttpCookieParser(attribute_names);
    
    cp.parse(cookie);
    
    assert (cp["_codespaces_hosted_edition_session"] == "BAh7BzoMdXNlcl9pZGkCXC46D3Nlc3Npb25faWQiJTY2NTQ0OWM0N2Q2NjlkZDY1OTY2MGYwZDY5MmYwY2M0--c5e3812e263d129b476cf498f369a07ecf822e86");;
    assert (cp["path"] == "/");
    assert (cp["HttpOnly"] == "");
}