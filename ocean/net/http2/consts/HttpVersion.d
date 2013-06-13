/******************************************************************************

    HTTP version identifier constants and enumerator

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    author:         David Eckardt

 ******************************************************************************/

module ocean.net.http2.consts.HttpVersion;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.stdc.ctype: isdigit;

/******************************************************************************

    HTTP version enumerator

 ******************************************************************************/

enum HttpVersion : ubyte
{
    Undefined = 0,
    v1_1,
    v1_0
}

/******************************************************************************

    HTTP version identifier string constants and enumerator value association

 ******************************************************************************/

struct HttpVersionIds
{
    /**************************************************************************

        HTTP version identifier string constants

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.1

     **************************************************************************/

    const char[][HttpVersion.max + 1] list =
    [
        HttpVersion.v1_1: "HTTP/1.1",
        HttpVersion.v1_0: "HTTP/1.0"
    ];

    /**************************************************************************

        Obtains the HTTP identifier string by version enumerator value. ver must
        be a HttpVersion value different from HttpVersion.Undefined.

        Params:
            ver = HTTP version enumerator value

         Returns:
             HTTP version identifier string corresponding to val

         Throws:
             assert()s that ver is in range and not HttpVersion.Undefined.

     **************************************************************************/

    static char[] opIndex ( HttpVersion ver )
    in
    {
        assert (ver,            "no version id for HttpVersion.Undefined");
        assert (ver <= ver.max, "invalid HttpVersion enumerator value");
    }
    body
    {
        return this.list[ver];
    }

    /**************************************************************************

        Obtains the HTTP version enumerator value by identifier string.

        Params:
            id = HTTP version identifier string

         Returns:
             Pointer to the HTTP version enumerator value corresponding to
             identifier string or null if the name identifier does not match any
             known HTTP version identifier string.

     **************************************************************************/

    static HttpVersion* opIn_r ( char[] id )
    {
        return id.length? id in this.codes : null;
    }

    /**************************************************************************

        Obtains the HTTP version enumerator value by identifier string. Does not
        throw an exception.

        Params:
            id = HTTP version identifier string

         Returns:
             HTTP version enumerator value corresponding to identifier string or
             HttpVersion.Undefined if the name string is unknown.

     **************************************************************************/

    static HttpVersion opIndex ( char[] id )
    {
        HttpVersion* code = opIn_r(id);

        return code? *code : (*code).Undefined;
    }

    /**************************************************************************

        Checks whether id has a valid syntax for a HTTP version identifier
        string:

        "HTTP" "/" 1*DIGIT "." 1*DIGIT

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html#sec3.1

        Params:
            id = HTTP version identifier string

         Returns:
             true if d has a valid syntax for a HTTP version identifier string
             or false otherwise.

     **************************************************************************/

    static bool validSyntax ( char[] id )
    {
        const prefix = "HTTP/";

        bool valid = id.length > prefix.length;

        if (valid)
        {
            valid = id[0 .. prefix.length] == prefix;
        }

        if (valid)
        {
            size_t n_before_dot = 0;

            foreach (i, c; id[prefix.length .. $])
            {
                if (!isdigit(c))
                {
                    if (c == '.')
                    {
                        n_before_dot = i;
                    }
                    else
                    {
                        valid = false;
                    }

                    break;
                }
            }

            valid &= n_before_dot != 0;

            if (valid)
            {
                size_t after_dot = n_before_dot + prefix.length + 1;

                valid &= id.length > after_dot;

                if (valid) foreach (i, c; id[after_dot .. $])
                {
                    if (!isdigit(c))
                    {
                        valid = false;
                        break;
                    }
                }
            }
        }

        return valid;
    }

    /**************************************************************************

        Unittest for validSyntax()

     **************************************************************************/

    unittest
    {
        assert (validSyntax("HTTP/1.1"));
        assert (validSyntax("HTTP/1.23"));
        assert (validSyntax("HTTP/123.456"));
        assert (!validSyntax("HTTP/123456"));
        assert (!validSyntax("HTTP/.123456"));
        assert (!validSyntax("HTTP/1,1"));
        assert (!validSyntax("HTTP/1."));
        assert (!validSyntax("HTTP/.1"));
        assert (!validSyntax("HTTP/."));
        assert (!validSyntax("HTTP/"));
        assert (!validSyntax(""));
    }

    /**************************************************************************

        HTTP version code enumerator value by name string

     **************************************************************************/

    private static HttpVersion[char[]] codes;

    /**************************************************************************

        Static constructor; populates this.codes

     **************************************************************************/

    static this ( )
    {
        foreach (i, str; this.list)
        {
            this.codes[str] = cast (HttpVersion) i;
        }

        this.codes.rehash;
    }

    /**************************************************************************/

    unittest
    {
        static assert(this.list[HttpVersion.v1_1]     == "HTTP/1.1");
        static assert(this.list[HttpVersion.v1_0]     == "HTTP/1.0");

        assert(!this.list[HttpVersion.Undefined].length);

        assert(this.list[HttpVersion.v1_1]     == "HTTP/1.1");
        assert(this.list[HttpVersion.v1_0]     == "HTTP/1.0");

        assert(typeof(*this)["HTTP/1.1"]     == HttpVersion.v1_1);
        assert(typeof(*this)["HTTP/1.0"]     == HttpVersion.v1_0);
        assert(typeof(*this)["SPAM"]         == HttpVersion.Undefined);
        assert(typeof(*this)[""]             == HttpVersion.Undefined);
        assert(typeof(*this)[null]           == HttpVersion.Undefined);

        HttpVersion* v = "HTTP/1.1" in typeof(*this);
        assert(v);
        assert(*v == (*v).v1_1);

        v = "HTTP/1.0" in typeof(*this);
        assert(v);
        assert(*v == (*v).v1_0);

        assert(!("SPAM" in typeof(*this)));
        assert(!(""     in typeof(*this)));
        assert(!(null   in typeof(*this)));
    }
}
