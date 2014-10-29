/*******************************************************************************

    Http Session "Cookie" Structure

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Apr 2010: Initial release

    author:         David Eckardt

    Reference:      RFC 2109

                    @see http://www.w3.org/Protocols/rfc2109/rfc2109.txt
                    @see http://www.servlets.com/rfcs/rfc2109.html

 ******************************************************************************/

module ocean.net.http.cookie.HttpCookieParser;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.net.util.QueryParams: QueryParamSet;

/******************************************************************************/

class HttpCookieParser : QueryParamSet
{
    this ( char[][] cookie_names ... )
    {
        super(';', '=', cookie_names);
    }
}

/******************************************************************************/

unittest
{
    const char[] cookie_header_value = "sonar=2649113645; sonar-expires=1383922851";

    const char[][] cookie_names =
    [
        "sonar",
        "sonar-expires"
    ];

    scope cookie = new HttpCookieParser(cookie_names);

    cookie.parse(cookie_header_value);

    assert (cookie["sonar"] == "2649113645");;
    assert (cookie["sonar-expires"] == "1383922851");
}