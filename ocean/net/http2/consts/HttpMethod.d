/******************************************************************************

    HTTP method name constants and enumerator

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    author:         David Eckardt

    TODO: add support for extension methods (when needed)

 ******************************************************************************/

module ocean.net.http2.consts.HttpMethod;

/******************************************************************************

    HTTP method enumerator

 ******************************************************************************/

enum HttpMethod : ubyte
{
    Undefined = 0,
    Get,
    Head,
    Post,
    Put,
    Delete,
    Trace,
    Connect,
    Options
}

/******************************************************************************

    HTTP method name string constants and enumerator value association

 ******************************************************************************/

struct HttpMethodNames
{
    /**************************************************************************

        HTTP method name string constants

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec5.html#sec5.1.1

     **************************************************************************/

    const char[][HttpMethod.max + 1] List =
    [
        HttpMethod.Undefined:  "",
        HttpMethod.Get:        "GET",
        HttpMethod.Head:       "HEAD",
        HttpMethod.Post:       "POST",
        HttpMethod.Put:        "PUT",
        HttpMethod.Delete:     "DELETE",
        HttpMethod.Trace:      "TRACE",
        HttpMethod.Connect:    "CONNECT",
        HttpMethod.Options:    "OPTIONS"
    ];

    /**************************************************************************

        HTTP method enumerator value by name string

     **************************************************************************/

    private static HttpMethod[char[]] methods_by_name;

    /**************************************************************************

        Obtains the HTTP method enumerator value by name string. Does not throw
        an exception.

        Params:
            name = HTTP method name string

         Returns:
             HTTP method enumerator value corresponding to name string or
             HttpMethod.Undefined if the name string is unknown.

     **************************************************************************/

    static HttpMethod opIndex ( char[] name )
    {
        HttpMethod* method = name? name in this.methods_by_name : null;

        return method? *method : HttpMethod.init;
    }

    /**************************************************************************

        Obtains the HTTP method name string by enumerator value. Does not throw
        an exception.

        Params:
            method = HTTP method enumerator value

         Returns:
             HTTP method name string corresponding to name method or null on
             invalid value.

     **************************************************************************/

    static char[] opIndex ( HttpMethod method )
    in
    {
        static assert (method.max < this.List.length);
    }
    body
    {
        return (method <= method.max)? this.List[method] : null;
    }

    /**************************************************************************

        Static constructor; populates the association map

     **************************************************************************/

    static this ( )
    {
        foreach (method, name; this.List)
        {
            this.methods_by_name[name] = cast (HttpMethod) method;
        }

        this.methods_by_name.rehash;
    }

    /**************************************************************************/

    unittest
    {
        static assert(this.List[HttpMethod.Get]     == "GET");
        static assert(this.List[HttpMethod.Head]    == "HEAD");
        static assert(this.List[HttpMethod.Post]    == "POST");
        static assert(this.List[HttpMethod.Put]     == "PUT");
        static assert(this.List[HttpMethod.Delete]  == "DELETE");
        static assert(this.List[HttpMethod.Trace]   == "TRACE");
        static assert(this.List[HttpMethod.Connect] == "CONNECT");
        static assert(this.List[HttpMethod.Options] == "OPTIONS");

        static assert(!this.List[HttpMethod.Undefined].length);

        assert(typeof(*this)[HttpMethod.Get]     == "GET");
        assert(typeof(*this)[HttpMethod.Head]    == "HEAD");
        assert(typeof(*this)[HttpMethod.Post]    == "POST");
        assert(typeof(*this)[HttpMethod.Put]     == "PUT");
        assert(typeof(*this)[HttpMethod.Delete]  == "DELETE");
        assert(typeof(*this)[HttpMethod.Trace]   == "TRACE");
        assert(typeof(*this)[HttpMethod.Connect] == "CONNECT");
        assert(typeof(*this)[HttpMethod.Options] == "OPTIONS");

        assert(!typeof(*this)[HttpMethod.Undefined].length);

        assert(typeof(*this)[cast(HttpMethod)(HttpMethod.max + 1)] is null);

        assert(typeof(*this)["GET"]     == HttpMethod.Get);
        assert(typeof(*this)["HEAD"]    == HttpMethod.Head);
        assert(typeof(*this)["POST"]    == HttpMethod.Post);
        assert(typeof(*this)["PUT"]     == HttpMethod.Put);
        assert(typeof(*this)["DELETE"]  == HttpMethod.Delete);
        assert(typeof(*this)["TRACE"]   == HttpMethod.Trace);
        assert(typeof(*this)["CONNECT"] == HttpMethod.Connect);
        assert(typeof(*this)["OPTIONS"] == HttpMethod.Options);

        assert(typeof(*this)["SPAM"]    == HttpMethod.Undefined);
        assert(typeof(*this)[""]        == HttpMethod.Undefined);
        assert(typeof(*this)[null]      == HttpMethod.Undefined);
    }
}
