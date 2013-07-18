/*******************************************************************************

    Struct containing parameters for curl.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        August: Initial release

    authors:        Gavin Norman, Hans Bjerkander

    Contains all the different parameters needed for creating a http request
    with curl.

*******************************************************************************/

module ocean.net.client.curl.process.RequestParams;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.ContextUnion;

private import ocean.net.client.curl.process.NotificationInfo;



/*******************************************************************************

    Alias for a delegate which is called when a chunk of data is received
    from a url.

*******************************************************************************/

public alias void delegate ( ContextUnion context, char[] url,
        ubyte[] data ) CurlReceiveDg;


/*******************************************************************************

    Alias for a delegate which is called when a download finishes.

*******************************************************************************/

public alias void delegate ( NotificationInfo info ) CurlNotificationDg;


/*******************************************************************************

    Template to encapsulate the de/serialization of a type. Delegates and unions
    are handled in this way as the struct serializer doesn't currently support
    serializing those types.

    TODO: update struct serializer to support serialization of delegates and
    unions.

*******************************************************************************/

private struct Serialized ( T )
{
    private ubyte[T.sizeof] serialized;

    public void set ( T value )
    {
        this.serialized[]  = (cast(ubyte*)&value)[0 .. value.sizeof];
    }

    public T get ( )
    {
        return *(cast(T*)this.serialized.ptr);
    }
}



public struct RequestParams
{
  /***************************************************************************

        Address of download.

    ***************************************************************************/

    public char[] url;


    /***************************************************************************

        Request command

    ***************************************************************************/

    public char[] req_command;


    /***************************************************************************

        Request data, can be empty

    ***************************************************************************/

    public char[] req_data;

    /***************************************************************************

        If set to 'true', req_data is interpreted as a file name to read from.

    ***************************************************************************/

    public bool req_is_file;

    /***************************************************************************

        Delegate to receive data from the request.

    ***************************************************************************/

    public Serialized!(CurlReceiveDg) receive_dg;


    /***************************************************************************

        Delegate to receive errors from the request.

    ***************************************************************************/

    public Serialized!(CurlReceiveDg) error_dg;


    /***************************************************************************

        Delegate to be called when the request finishes.

    ***************************************************************************/

    public Serialized!(CurlNotificationDg) notification_dg;


    /***************************************************************************

        Username & password to use for request authentication. Set using
        the authenticate() method.

    ***************************************************************************/

    public char[] username;

    public char[] passwd;


    /***************************************************************************

        request timeout (in seconds). Set using the timeout() method.

    ***************************************************************************/

    public uint timeout_s;

    /***************************************************************************

        Speed time (in seconds) and amount (in bytes).
        Set using the speedTimeout() method.

    ***************************************************************************/

    public uint speedtime_s;          // this is 32 bits in the curl source

    public uint speedlimit_bytes_sec; // this is 32 bits in the curl source


    /***************************************************************************

        Flag set to true if "insecure" SSL transfers are enabled.

    ***************************************************************************/

    public bool ssl_insecure;


    /***************************************************************************

        Flag set to true to download header only

    ***************************************************************************/

    public bool header_only;

    /***************************************************************************

        Flag set to true to download header and the body

    ***************************************************************************/

    public bool header_and_body;


    /***************************************************************************

        Flag set to true to follow redirects (HTTP header 3XX response codes)

    ***************************************************************************/

    public bool follow_redirects;


    /***************************************************************************

        Maximum number of redirects to use (ignored unless following redirects)

    ***************************************************************************/

    public int max_redirects;


    /***************************************************************************

        To be used when extra information is needed to be add to the header.

    ***************************************************************************/

    public char[][] extra_header_params;


    /***************************************************************************

        To be used to emulate a filled-in form (curl -F)

    ***************************************************************************/

    public char[][] form_params;

    /***************************************************************************

        To spoof a user agent string (curl -A)

    ***************************************************************************/

    public char[] user_agent_string;

    /***************************************************************************

        User-defined context associated with download. Set using the
        context() methods.

    ***************************************************************************/

    public Serialized!(ContextUnion) context;


    /***************************************************************************

        Returns:
            true if this download is set to use authentication (by a call to
            the authenticate() method)

    ***************************************************************************/

    public bool authentication_set ( )
    {
        return this.username.length > 0 && this.passwd.length > 0;
    }


    /***************************************************************************

        Returns:
            true if this download is set to use a timeout (by a call to the
            timeout() method)

    ***************************************************************************/

    public bool timeout_set ( )
    {
        return this.timeout_s > 0;
    }


    /***************************************************************************

        Returns:
            true if "insecure" SSL downloads are enabled

    ***************************************************************************/

    public bool ssl_insecure_set ( )
    {
        return this.ssl_insecure;
    }

    /***************************************************************************

        Returns:
            true if a minimum speed limit has been set

    ***************************************************************************/

    public bool speed_timeout_set ( )
    {
        return this.speedlimit_bytes_sec > 0 && this.speedtime_s > 0;
    }

    /***************************************************************************

        Returns:
            true if want header only

    ***************************************************************************/

    public bool header_only_set ( )
    {
        return this.header_only;
    }

    /***************************************************************************

        Returns:
            true if want header and the body

    ***************************************************************************/

    public bool header_and_body_set ( )
    {
        return this.header_and_body;
    }

    /***************************************************************************

        Returns:
            true if more information should be added to the header.

    ***************************************************************************/

    public bool extra_header_set ( )
    {
        return this.extra_header_params.length > 0;
    }
}
