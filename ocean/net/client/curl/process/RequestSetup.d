/*******************************************************************************

    Mixins for request structs used in CurlProcess*.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        August 2012: Initial release

    authors:        Gavin Norman, Hans Bjerkander

    Contains different templates for different http requests. Combinations of
    this templates creates a struct that can be used as a request.

*******************************************************************************/

module ocean.net.client.curl.process.RequestSetup;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.net.client.curl.process.RequestParams;

/*******************************************************************************

    Mixin for the methods shared by all different HTTP requests

*******************************************************************************/

public template RequestBase ( )
{

    /***************************************************************************

        Invariant to make sure that this object only can be created with opcall

    ***************************************************************************/

    invariant ( )
    {
        assert(this.params.url && this.params.req_command,
            "Invalid request object -- command not set");
    }

    /***************************************************************************

        Struct containing the different paramaters that can be used. To set the
        parameters use methods in the templates.

    ***************************************************************************/

    private RequestParams params;

    /***************************************************************************

        Sets the download context from a Context instance.

        Params:
            context = context to set for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( ContextUnion context )
    {
        this.params.context.set(context);
        return this;
    }


    /***************************************************************************

        Sets the download context from an object reference.

        Params:
            object = context to set as context for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( Object object )
    {
        this.params.context.set(ContextUnion(object));
        return this;
    }


    /***************************************************************************

        Sets the download context from a pointer.

        Params:
            pointer = pointer to set as context for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( void* pointer )
    {
        this.params.context.set(ContextUnion(pointer));
        return this;
    }


    /***************************************************************************

        Sets the download context from a hash (integer).

        Params:
            integer = integer to set as context for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( hash_t integer )
    {
        this.params.context.set(ContextUnion(integer));
        return this;
    }


    /***************************************************************************

        Sets this download to use authentication with the specified username
        and password.

        Params:
            username = authentication username
            passwd = authentication password

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) authenticate ( char[] username, char[] passwd )
    {
        this.params.username = username;
        this.params.passwd = passwd;
        return this;
    }


    /***************************************************************************

        Sets this download to timeout after the specified time.

        Params:
            s = seconds to timeout after

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) timeout ( uint s )
    {
        this.params.timeout_s = s;
        return this;
    }


    /***************************************************************************

        Sets this download to allow "insecure" SSL connections and transfers.

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) sslInsecure ( )
    {
        this.params.ssl_insecure = true;
        return this;
    }


    /***************************************************************************

        Sets this download to allow "insecure" SSL connections and transfers.

        Returns:
            this pointer for method chaining

        Deprecated: v1.1
            Renamed to sslInsecure.

    ***************************************************************************/

    deprecated alias sslInsecure ssl_insecure;


    /***************************************************************************

        Sets this download to download the header and the body if the
        the include_body is set, otherwise only the header is downloaded

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) header ( bool include_body )
    {
        if ( include_body )
        {
            this.params.header_and_body = true;
        }
        else
        {
            this.params.header_only = true;
        }
        return this;
    }


    /***************************************************************************

        Set this download to follow redirects (HTTP header 3XX response codes)

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) followRedirects ( )
    {
        this.params.follow_redirects = true;
        return this;
    }


    /***************************************************************************

        Set this download to follow redirects (HTTP header 3XX response codes)

        Returns:
            this pointer for method chaining

        Deprecated: v1.1
            Renamed to followRedirects.
    ***************************************************************************/

    deprecated alias followRedirects follow_redirects;


    /***************************************************************************

        Maximum number of redirects to use (ignored unless following redirects)
        If this is not set, the curl default (50 redirects) will be used.

        Params:
            redirects = maximum number of redirection-followings allowed. Must
                        be >= 0.

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) maxRedirects ( int redirects )
    {
        // BUG in cURL: According to the curl manual, you can use -1 to have no
        // limit on the number of redirections. However, the command line does
        // not parse it!

        assert(redirects >= 0);
        this.params.max_redirects = redirects;
        return this;
    }

    /***************************************************************************

        Adds extra information in the header

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) extraHeader ( char[] header )
    {
        if ( header.length )
        {
            this.params.extra_header_params ~= header;
        }
        return this;
    }

    /***************************************************************************

        Specify the user agent string (used for spoofing)

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) userAgent ( char[] agent )
    {
        this.params.user_agent_string = agent;

        return this;
    }

    /***************************************************************************

        Adds a form parameter

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) addForm ( char[] form )
    {
        if ( form.length )
        {
            this.params.form_params ~= form;
        }
        return this;
    }


    /***************************************************************************

        "Constructor" method. Creates an instance of this struct from the given
        parameters. This struct is essentially a wrapper around a RequestParams
        struct which opens only certain methods to use.

        Params:
            url = url to request
            recieve_dg = delegate to which request data is passed
            error_dg = delegate to which error messages are passed
            notification_dg = delegate to which notifications of states changes
                are sent (when a request is queued / started / finished)
            data = the data that will be "posted"

    ***************************************************************************/

    public static typeof(*this) opCall ( char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg notification_dg ,
            char[] cmd)
    {
        typeof(*this) req;

        req.params.url = url;
        req.params.receive_dg.set      ( receive_dg );
        req.params.error_dg.set        ( error_dg   );
        req.params.notification_dg.set ( notification_dg );
        req.params.req_command = cmd;

        return req;
    }
}

/*******************************************************************************

    Mixin for a request with data

*******************************************************************************/

public template RequestData ( )
{

    /***************************************************************************

        Set the data, which will be sent with the request

        Args:
            data = the data to be sent with the request

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) setRequestData ( char[] data )
    {
        this.params.req_data = data;
        return this;
    }
}

