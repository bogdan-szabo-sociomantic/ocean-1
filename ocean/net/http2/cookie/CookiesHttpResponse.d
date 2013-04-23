/******************************************************************************

    HTTP response message generator with support for cookies

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    author:         David Eckardt

    Takes a list of HttpCookieGenerator instances in the constructor. When
    rendering the response by CookiesHttpResponse.render(), a Set-Cookie header
    line will be added for each HttpCookieGenerator instance a cookie value is
    assigned to.
    CookiesHttpResponse.reset() calls reset() on all cookies.

 ******************************************************************************/

module ocean.net.http2.cookie.CookiesHttpResponse;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.http2.HttpResponse;
private import ocean.net.http2.cookie.HttpCookieGenerator;
private import ocean.net.http2.consts.HeaderFieldNames;

/******************************************************************************/

class CookiesHttpResponse : HttpResponse
{
    /**************************************************************************

        List of cookies. render() adds a Set-Cookie header line will for each
        cookie to which a value was assigned to after the last reset().

     **************************************************************************/

    public const HttpCookieGenerator[] cookies;

    /**************************************************************************

        Constructor

        Params:
            cookies = cookies to use

     **************************************************************************/

    public this ( HttpCookieGenerator[] cookies ... )
    out
    {
        foreach (cookie; this.cookies)
        {
            assert (cookie !is null, "null cookie instance");
        }
    }
    body
    {
        this.cookies = cookies.dup; // No .dup caused segfaults, apparently the
                                    // array is then sliced. 
        super.addKey(HeaderFieldNames.ResponseNames.SetCookie);
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();

        foreach (ref cookie; this.cookies)
        {
            delete cookie;

            cookie = null;
        }

        delete this.cookies;
    }

    /**************************************************************************

        Called by render() when the Set-Cookie header lines should be appended.

        Params:
            append = header line appender

     **************************************************************************/

    protected override void addHeaders ( AppendHeaderLines append )
    {
        foreach (cookie; this.cookies) if (cookie.value)
        {
            scope append_line = append.new IncrementalValue("Set-Cookie");

            cookie.render(&append_line.appendToValue);
        }
    }

    /**************************************************************************

        Called by reset(), resets the cookies.

     **************************************************************************/

    public override void reset ( )
    {
        super.reset();

        foreach (cookie; this.cookies)
        {
            cookie.reset();
        }
    }
}
