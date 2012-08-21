/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        August: Initial release

    authors:        Hans Bjerkander

    Contains all the different parameters needed for creating a hhtp request
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

        Request command, if empty GET will be used

    ***************************************************************************/

    public Serialized!(char[][]) req_command;


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

        Flag set to true if "insecure" SSL transfers are enabled.

    ***************************************************************************/

    public bool ssl_insecure;


    /***************************************************************************

        To be used when extra information is needed to be add to the header. 

    ***************************************************************************/

    public char[][] extra_header_params;


    /***************************************************************************

        User-defined context associated with download. Set using the
        context() methods.

    ***************************************************************************/

    public Serialized!(ContextUnion) context;


    /***************************************************************************

        Should the last 3 bytes of the standard output be the http status code?

    ***************************************************************************/

    public bool append_statuscode = true;


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
            true if more information should be added to the header.

    ***************************************************************************/

    public bool extra_header_set ( )
    {
        return this.extra_header_params.length > 0;
    }


    /***************************************************************************

        Returns:
            true if request command set.

    ***************************************************************************/

    public bool req_command_set ( )
    {
        return this.req_command.get().length > 0;   
    }


    /***************************************************************************

        Returns:
           true if the last 3 bytes of the output should be the http statuscode.

    ***************************************************************************/

    public bool appendStatusCode( )
    {
        return this.append_statuscode;
    }


    /***************************************************************************

        Getter and Setter methods for variables with the type struct template
        Serialized ( T ). Calls the set and get method from the template.

    ***************************************************************************/

    public CurlReceiveDg get_receive_dg()
    {
        return this.receive_dg.get();
    }


    public void set_receive_dg( CurlReceiveDg dg)
    {
        this.receive_dg.set(dg);
    }


    public CurlReceiveDg get_error_dg()
    {
        return this.error_dg.get();
    }


    public void set_error_dg( CurlReceiveDg dg)
    {
        this.error_dg.set(dg);
    }


    public CurlNotificationDg get_notification_dg()
    {
        return this.notification_dg.get();
    }


    public void set_notification_dg(CurlNotificationDg dg)
    {
        this.notification_dg.set(dg);
    }


    public ContextUnion get_context()
    {
        return this.context.get();   
    }


    public void set_context(ContextUnion c)
    {
        this.context.set(c);
    }

    public char[][] get_req_command()
    {
        return req_command.get();
    }

    public void set_req_command(char[][] req)
    {
        this.req_command.set(req.dup);//do I need to dup?
    }
}