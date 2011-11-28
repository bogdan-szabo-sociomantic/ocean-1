/*******************************************************************************

    Http Session "Cookie" Structure

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        Apr 2010: Initial release

    author:         David Eckardt

    Reference:      RFC 2109, http://www.servlets.com/rfcs/rfc2109.html

    Note:

    Usage Example:

     ---

        import $(TITLE);


        char[] cookie_header_line;

        HttpCookie cookie;

        cookie.attributes["max"] = "moritz";
        cookie.path              = "/mypath/";

        cookie.write(cookie_header_line);

        // cookie_header_line now contains "max=moritz; Path=/mypath/"

        cookie_header_line = "MaxAge=4711; eggs=ham; Version=1";

        cookie.read(cookie_header_line);

        // cookie.attributes now contains {"eggs" => "ham"}
        // cookie.max_age now equals 4711
        // cookie.comment, cookie.domain, cookie.path, are empty
        // cookie.secure is false (default value)


     ---


 ******************************************************************************/

module ocean.net.http.HttpCookie;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.http.HttpConstants: HttpCookieAttr;

private import ocean.net.http.HttpTime;

private import ocean.text.util.StringSearch;

private import ocean.core.Array: copy;

private import tango.stdc.string: memchr;

/******************************************************************************

    HttpCookie structure

 ******************************************************************************/

struct HttpCookie
{
    /**************************************************************************

        Version as mandated in RFC 2109, 4.2.2

     **************************************************************************/

    public const  Version = '1';

    /**************************************************************************

        Predefined attributes

        A default value makes an attribute not appear in the cookie header line.

     **************************************************************************/

    public char[] comment = ``,
                  domain  = ``,
                  path    = ``;

    public bool   secure  = false;

    /**************************************************************************

        Custom attributes

        Attribute values are optional; set to an empty string to indicate no
        value for a particular attribute.

     **************************************************************************/

    char[][char[]] attributes;

    /**************************************************************************

        Cookie expiration time (UNIX time)

     **************************************************************************/

    private time_t expires_;

    /**************************************************************************

        Cookie expiration set flag

     **************************************************************************/

    private bool   expires_enabled_ = false;

    /**************************************************************************

        HTTP cookie header line buffer, shared between read() and write()

     **************************************************************************/

    private char[] line;

    /**************************************************************************

        Reused array of slices to line, used by read()

     **************************************************************************/

    private char[][] slices;

    /**************************************************************************

        Sets end enables the cookie expiration time

        Params:
            expires_ = cookie expiration time (UNIX time)

        Returns:
            cookie expiration time (UNIX time)

     **************************************************************************/

    public time_t expires ( time_t expires_ )
    {
        this.expires_     = expires_;
        this.expires_enabled_ = true;

        return expires_;
    }

    /**************************************************************************

        Returns:
            cookie expiration time (UNIX time); valid only if expires_enabled()
            returns true

     **************************************************************************/

    public time_t expires ( )
    {
        return this.expires_;
    }

    /**************************************************************************

        Returns:
            true if cookie expiration is enabled or false otherwise

     **************************************************************************/

    public bool expires_enabled ( )
    {
        return this.expires_enabled_;
    }

    /**************************************************************************

        Clears the cookie expiration

        Returns:
            true if cookie expiration was enabled or false otherwise

     **************************************************************************/

    public bool disableExpires ( )
    {
        scope (exit) this.expires_enabled_ = false;
        return this.expires_enabled_;
    }

    /**************************************************************************

        Generates the cookie header line.

        Params:
            line_out: cookie header line output: exposes an internal buffer
                      which is overwritten by read() and reset(), do not modify

        Returns:
            true if any attribute was set or false otherwise. In case of false
            line_out is an empty string.

     **************************************************************************/

    public char[] write ( )
    {
        this.line.length = 0;

        if (this.isSet())
        {
            bool subsequent = false;

            foreach (name, value; this.attributes)
            {
                this.appendAttribute(subsequent, name, value);
            }

            this.appendStdAttribute(subsequent, HttpCookieAttr.Name.Comment, this.comment);

            if (this.expires_enabled_)
            {
                this.appendExpires(subsequent);
            }

            this.appendStdAttribute(subsequent, HttpCookieAttr.Name.Path,    this.path);
            this.appendStdAttribute(subsequent, HttpCookieAttr.Name.Domain,  this.domain);

            if (this.secure)
            {
                this.appendAttribute(subsequent, HttpCookieAttr.Name.Secure);
            }
            //line ~= this.formatAttr(HttpCookieAttr.Name.Version, [this.Version]);
        }

        return this.line;
    }


    /**************************************************************************

        Reads a cookie header line and retrieves the attributes from it.

        Params:
            line: input cookie header line

        Returns:
            true if any attribute was retrieved or false otherwise. In case of
            false all attributes are at default values or empty.

     **************************************************************************/

    public bool read ( char[] line_in )
    {
        bool is_set = false;

        this.reset();

        if (line_in.length)
        {
            this.line.copy(line_in);

            foreach (item; StringSearch!().split(this.slices, this.line, HttpCookieAttr.Delim.Attributes))
            {
                char[] chunk = StringSearch!().trim(item);

                if (chunk.length)
                {
                    StringSearch!().strToLower(chunk);

                    char* delim = cast (char*) memchr(chunk.ptr, HttpCookieAttr.Delim.AttrValue, chunk.length);

                    if (delim)
                    {
                        size_t n = delim - chunk.ptr;

                        this.attributes[chunk[0 .. n]] = chunk[n + 1 .. $];
                    }
                    else
                    {
                        this.attributes[chunk] = "";
                    }
                }
            }
        }

        return is_set;
    }

    /**************************************************************************

        Tells whether custom attributes are set.

     **************************************************************************/

    public bool isSet ()
    {
        return !!this.attributes.length;
    }

    /**************************************************************************

        Resets all attributes.

     **************************************************************************/

    public typeof (this) reset ()
    {
        foreach (key; this.attributes.keys)
        {
            this.attributes.remove(key);
        }

        this.line.length = 0;

        this.comment.length    = 0;
        this.domain.length     = 0;
        this.path.length       = 0;
        this.slices.length     = 0;

        this.secure            = false;
        this.expires_enabled_  = false;

        return this;
    }

    /**************************************************************************

        Appends "name=value" (if value is not empty) or "name" (if value is
        empty) to this.line, prepending a delimiter if subsequent is true. Does
        nothing if value is empty.

        Params:
            subsequent = true input indicates that a delimiter must be
                         prepended; will be changed to true if false and value
                         non-empty.
            name       = attribute name
            value      = attribute value (optional)

         Returns:
             appended string which is empty if value is an empty string (but
             never null)

     **************************************************************************/

    private char[] appendStdAttribute ( ref bool subsequent, char[] name, char[] value )
    {
        return value.length? this.appendAttribute(subsequent, name, value): "";
    }

    /**************************************************************************

        Appends "name=value" (if value is not empty) or "name" (if value is
        empty) to this.line, prepending a delimiter if subsequent is true.

        Params:
            subsequent = true input indicates that a delimiter must be
                         prepended; will be changed to true if false.
            name       = attribute name
            value      = attribute value (optional)

         Returns:
             appended string

     **************************************************************************/

    private char[] appendAttribute ( ref bool subsequent, char[] name, char[] value = "" )
    {
        size_t pos = this.line.length;

        if (subsequent)
        {
             const separator = [HttpCookieAttr.Delim.Attributes, ' '];

             this.line ~= separator;
        }
        else
        {
            subsequent = true;
        }

        this.line ~= name;

        if (value.length != 0)
        {
            this.line ~= HttpCookieAttr.Delim.AttrValue;
        }

        this.line ~= value;

        return this.line[pos .. $];
    }


    /**************************************************************************

        If expiration is enabled, appends the expiration standard cookie
        argument to this line, using the current expiration time, prepending a
        delimiter if subsequent is true. Does nothing if expiration is disabled.

        Params:
            subsequent = true input indicates that a delimiter must be
                         prepended; will be changed to true if false and
                         expiration enabled.

         Returns:
             appended string which is empty if expiration was disabled (but
             never null)

     **************************************************************************/

    private char[] appendExpires ( ref bool subsequent )
    {
        size_t pos = this.line.length;

        if (subsequent)
        {
             const Prefix = HttpCookieAttr.Delim.Attributes ~ (' ' ~
                            HttpCookieAttr.Name.Expires) ~
                            HttpCookieAttr.Delim.AttrValue;

             this.line ~= Prefix;
        }
        else
        {
            const Prefix = HttpCookieAttr.Name.Expires ~ HttpCookieAttr.Delim.AttrValue;
            this.line ~= Prefix;

            subsequent = true;
        }

        return HttpTime.append(this.line, this.expires_)[pos .. $];
    }
}

/******************************************************************************

    Unittest

 ******************************************************************************/

unittest
{
    HttpCookie cookie;

    cookie.read("sonar=1127529181; sonar-expires=1362077071; spam");

    char[]* value = "sonar" in cookie.attributes;
    assert (value !is null);
    assert (*value  == "1127529181");

    value = "sonar-expires" in cookie.attributes;
    assert (value !is null);
    assert (*value  == "1362077071");

    value = "spam" in cookie.attributes;
    assert (value !is null);
    assert ((*value).length == 0);

    cookie.reset();

    assert (!("sonar" in cookie.attributes));
    assert (!("sonar-expires" in cookie.attributes));
    assert (!("spam" in cookie.attributes));

    cookie.attributes["eggs"]    = "abc";
    cookie.attributes["spam"]    = "xyz";
    cookie.attributes["sausage"] = "";

    cookie.expires = 352716455;
    cookie.domain  = "example.net";

    assert (cookie.expires_enabled);

    char[] cookie_line = cookie.write().dup;

    assert (cookie_line.length);

    cookie.disableExpires();

    assert (!cookie.expires_enabled);

    cookie.reset();

    assert (cookie.write().length == 0);

    cookie.read(cookie_line);

    value = "sausage" in cookie.attributes;
    assert (value !is null);
    assert ((*value).length == 0);

    value = "eggs" in cookie.attributes;
    assert (value !is null);
    assert (*value == "abc");

    value = "spam" in cookie.attributes;
    assert (value !is null);
    assert (*value == "xyz");


}

/******************************************************************************

    Performance test and example cookie header line output

 ******************************************************************************/

debug (OceanUnitTest)
{
    import tango.io.Stdout;

    import tango.core.internal.gcInterface: gc_disable, gc_enable;

    unittest
    {
        HttpCookie cookie;

        /**********************************************************************

            Example cookie header line output. The cookies header line write()
            generates cannot be checked by comparing against an expected string
            constant because the order of attributes is not specified. So it is
            much easier for a human to read the line printed to the console and
            check for correctness.

         **********************************************************************/

        HttpTime   httptime;

        cookie.domain  = "example.net";
        cookie.path    = "/";
        cookie.comment = "Want a cookie?";
        cookie.expires = 352716455;
        cookie.secure  = true;

        cookie.attributes["eggs"]    = "abc";
        cookie.attributes["spam"]    = "xyz";
        cookie.attributes["sausage"] = "";

        Stderr.formatln("\nHttpCookie attributes:\n"
                        "\tdomain  = {}\n"
                        "\tpath    = {}\n"
                        "\tcomment = {}\n"
                        "\texpires = {} ({})\n"
                        "\tsecure  = {}\n"
                        "\tfurther attributes: {}\n"
                        "\ncookie header line:\n\t{}\n",
                        cookie.domain, cookie.path, cookie.comment,
                        cookie.expires, httptime(cookie.expires), cookie.secure,
                        cookie.attributes, cookie.write());

        /**********************************************************************

            Read performance test. Note that this does not work with the GC
            disabled because the associative array of attributes is cleared and
            newly populated on each read(). However, this test at least ensures
            that the memory consumption does not increase under full load.

         **********************************************************************/

        const N = 50_000;

        Stderr.formatln("HttpCookie performance test: {} read cycles", N * 100).flush();

        for (uint i = 0; i < 100; i++)
        {
            for (uint j = 0; j < N; j++)
            {
                cookie.read("sonar=1127529181; sonar-expires=1362077071; spam");
            }

            Stderr.format("{,8}", (i + 1) * N);
            Stderr("\b\b\b\b\b\b\b\b").flush();
        }

        /**********************************************************************

            Write performance test with disabled GC

         **********************************************************************/

        Stderr.formatln("HttpCookie performance test: {} write cycles", N * 100).flush();

        cookie.reset();

        cookie.domain  = "example.net";
        cookie.path    = "/";
        cookie.comment = "Want a cookie?";
        cookie.expires = 352716455;
        cookie.secure  = true;

        cookie.attributes["eggs"]    = "abc";
        cookie.attributes["spam"]    = "xyz";
        cookie.attributes["sausage"] = "";

        {
            gc_disable();
            scope (exit) gc_enable();

            for (uint i = 0; i < 100; i++)
            {
                for (uint j = 0; j < N; j++)
                {
                    char[] header_line = cookie.write();
                }

                Stderr.format("{,8}", (i + 1) * N);
                Stderr("\b\b\b\b\b\b\b\b").flush();
            }
        }

        Stderr("HttpCookie performance test finished\n").flush();
    }
}