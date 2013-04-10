/*******************************************************************************

    HTTP Cookie Generator

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        December 2011: Initial release

    author:         David Eckardt

    Reference:      RFC 2109

                    @see http://www.w3.org/Protocols/rfc2109/rfc2109.txt
                    @see http://www.servlets.com/rfcs/rfc2109.html

 ******************************************************************************/

module ocean.net.http2.cookie.HttpCookieGenerator;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.util.ParamSet;

private import ocean.net.http2.consts.CookieAttributeNames;

private import ocean.net.http2.time.HttpTimeFormatter;

private import tango.stdc.time: time_t;

/******************************************************************************/

class HttpCookieGenerator : ParamSet
{
    /**************************************************************************

        Cookie ID

     **************************************************************************/

    public const char[] id;

    /**************************************************************************

        Cookie domain and path

     **************************************************************************/

    public char[] domain, path;

    /**************************************************************************

        Expiration time manager

     **************************************************************************/

    private static class ExpirationTime
    {
        /**********************************************************************

            Expiration time if set.

         **********************************************************************/

        private time_t t;

        /**********************************************************************

            true if the expiration time is currently defined or false otherwise.

         **********************************************************************/

        private bool is_set_ = false;

        /**********************************************************************

            Sets the expiration time.

            Params:
                t = expiration time

            Returns:
                t

            In:
                t must be at least 0.

         **********************************************************************/

        public time_t opAssign ( time_t t )
        in
        {
            assert (t >= 0, "negative time value");
        }
        body
        {
            this.is_set_ = true;
            return this.t = t;
        }

        /**********************************************************************

            Marks the expiration time as "not set".

         **********************************************************************/

        public void clear ( )
        {
            this.is_set_ = false;
        }

        /**********************************************************************

            Returns:
                true if the expiration time is currently defined or false
                otherwise.

         **********************************************************************/

        public bool is_set ( )
        {
            return this.is_set_;
        }

        /**********************************************************************

            Obtains the expiration time.

            Params:
                t = destination variable, will be set to the expiration time if
                    and only if an expiration time is currently defined.

            Returns:
                true if an expiration time is currently defined and t has been
                set to it or false otherwise.

         **********************************************************************/

        public bool get ( ref time_t t )
        {
            if (this.is_set_)
            {
                t = this.t;
            }

            return this.is_set_;
        }
    }

    /**************************************************************************

        Expiration time manager with string formatter

     **************************************************************************/

    private static class FormatExpirationTime : ExpirationTime
    {
        /**********************************************************************

            String formatter

         **********************************************************************/

        private HttpTimeFormatter formatter;

        /**********************************************************************

            Returns:
                current expiration time as HTTP time string or null if currently
                no expiration time is defined.

         **********************************************************************/

        public char[] format ( )
        {
            return super.is_set_? this.formatter.format(super.t) : null;
        }
    }

    /**************************************************************************

        Expiration time manager instance

     **************************************************************************/

    public  const ExpirationTime       expiration_time;

    /**************************************************************************

        Expiration time manager/formatter instance

     **************************************************************************/

    private const FormatExpirationTime fmt_expiration_time;

    /**************************************************************************

        Constructor

        Params:
            id              = cookie ID
            attribute_names = cookie attribute names

     **************************************************************************/

    this ( char[] id, char[][] attribute_names ... )
    {
        super.addKeys(this.id = id);

        super.addKeys(attribute_names);

        super.rehash();

        this.expiration_time = this.fmt_expiration_time = new FormatExpirationTime;
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.fmt_expiration_time;
    }

    /**************************************************************************

        Sets the cookie value.

        Params:
            val = cookie value string

        Returns:
            cookie value

     **************************************************************************/

    char[] value ( char[] val )
    {
        return super[this.id] = val;
    }

    /**************************************************************************

        Returns:
            the current cookie value

     **************************************************************************/

    char[] value ( )
    {
        return super[this.id];
    }

    /**************************************************************************

        Renders the HTTP response Cookie header line field value.

        Params:
            appendContent: callback delegate that will be invoked repeatedly
            to concatenate the Cookie header line field value.

     **************************************************************************/

    void render ( void delegate ( char[] str ) appendContent )
    {
        uint i = 0;

        void append ( char[] key, char[] val )
        {
            if (val)
            {
                if (i++)
                {
                    appendContent("; ");
                }

                appendContent(key);
                appendContent("=");
                appendContent(val);
            }
        }

        foreach (key, val; super)
        {
            append(key, val);
        }

        append(CookieAttributeNames.Names.Domain,  this.domain);
        append(CookieAttributeNames.Names.Path,    this.path);
        append(CookieAttributeNames.Names.Expires, this.fmt_expiration_time.format());
    }

    /**************************************************************************

        Clears the expiration time.

     **************************************************************************/

    public override void reset ( )
    {
        super.reset();

        this.expiration_time.clear();
    }
}

