/*******************************************************************************

    Download setup struct.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        January 2012: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.net.client.curl.process.DownloadSetup;



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


/*******************************************************************************

    Curl download setup struct. Instances of this struct can only be
    created externally by calling the download() method (in CurlProcessMulti).
    The method initialises a struct instance with the required parameters, then
    the struct provides methods to set the optional properties of a
    connection. When all options have been set the struct should be passed
    to the assign() method (see below).

*******************************************************************************/

public struct DownloadSetup
{
    /***************************************************************************

        Address of download.

    ***************************************************************************/

    private char[] url_;


    /***************************************************************************

        Delegate to receive data from the download.

    ***************************************************************************/

    private Serialized!(CurlReceiveDg) receive_dg_;


    /***************************************************************************

        Delegate to receive errors from the download.

    ***************************************************************************/

    private Serialized!(CurlReceiveDg) error_dg_;


    /***************************************************************************

        Delegate to be called when the download finishes.

    ***************************************************************************/

    private Serialized!(CurlNotificationDg) notification_dg_;


    /***************************************************************************

        Username & password to use for download authentication. Set using
        the authenticate() method.

    ***************************************************************************/

    private char[] username_;

    private char[] passwd_;


    /***************************************************************************

        Download timeout (in seconds). Set using the timeout() method.

    ***************************************************************************/

    private uint timeout_s_;


    /***************************************************************************

        Flag set to true if "insecure" SSL transfers are enabled.

    ***************************************************************************/

    private bool ssl_insecure_;


    /***************************************************************************

        User-defined context associated with download. Set using the
        context() methods.

    ***************************************************************************/

    private Serialized!(ContextUnion) context_;


    /***************************************************************************

        "Constructor" method. Creates an instance of this struct from the given
        parameters. As all members of the struct are private, this is
        essentially the only way an instance can be set up.

        Params:
            url = url to download
            recieve_dg = delegate to which downloaded data is passed
            error_dg = delegate to which error messages are passed
            notification_dg = delegate to which notifications of states changes
                are sent (when a download is queued / started / finished)

    ***************************************************************************/

    public static typeof(*this) opCall ( char[] url, CurlReceiveDg receive_dg,
            CurlReceiveDg error_dg, CurlNotificationDg notification_dg )
    {
        DownloadSetup download;

        download.url_ = url;
        download.receive_dg_.set(receive_dg);
        download.error_dg_.set(error_dg);
        download.notification_dg_.set(notification_dg);

        return download;
    }


    /***************************************************************************

        Url getter.

        Returns:
            download url

    ***************************************************************************/

    public char[] url ( )
    {
        return this.url_;
    }


    /***************************************************************************

        Receive delegate getter.

        Returns:
            receive delegate

    ***************************************************************************/

    public CurlReceiveDg receive_dg ( )
    {
        return this.receive_dg_.get;
    }


    /***************************************************************************

        Error delegate getter.

        Returns:
            error delegate

    ***************************************************************************/

    public CurlReceiveDg error_dg ( )
    {
        return this.error_dg_.get;
    }


    /***************************************************************************

        Notification delegate getter.

        Returns:
            notification delegate

    ***************************************************************************/

    public CurlNotificationDg notification_dg ( )
    {
        return this.notification_dg_.get;
    }


    /***************************************************************************

        Donwload context getter.

        Returns:
            user-specified download context

    ***************************************************************************/

    public ContextUnion context ( )
    {
        return this.context_.get;
    }


    /***************************************************************************

        Authentication username getter.

        Returns:
            authentication username, of 0 length if authentication not set

    ***************************************************************************/

    public char[] username ( )
    {
        return this.username_;
    }
    

    /***************************************************************************

        Authentication password getter.

        Returns:
            authentication password, of 0 length if authentication not set

    ***************************************************************************/

    public char[] passwd ( )
    {
        return this.passwd_;
    }


    /***************************************************************************

        Timeout getter.

        Returns:
            timeout is seconds, 0 if timeout not set

    ***************************************************************************/

    public uint timeout_s ( )
    {
        return this.timeout_s_;
    }


    /***************************************************************************

        Sets the download context from a Context instance.

        Params:
            context = context to set for download

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) context ( ContextUnion context )
    {
        this.context_.set(context);
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
        this.context_.set(ContextUnion(object));
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
        this.context_.set(ContextUnion(pointer));
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
        this.context_.set(ContextUnion(integer));
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
        this.username_ = username;
        this.passwd_ = passwd;
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
        this.timeout_s_ = s;
        return this;
    }


    /***************************************************************************

        Sets this download to allow "insecure" SSL connections and transfers.

        Returns:
            this pointer for method chaining

    ***************************************************************************/

    public typeof(this) ssl_insecure ( )
    {
        this.ssl_insecure_ = true;
        return this;
    }


    /***************************************************************************

        Returns:
            true if this download is set to use authentication (by a call to
            the authenticate() method)

    ***************************************************************************/

    public bool authentication_set ( )
    {
        return this.username_.length > 0 && this.passwd_.length > 0;
    }


    /***************************************************************************

        Returns:
            true if this download is set to use a timeout (by a call to the
            timeout() method)

    ***************************************************************************/

    public bool timeout_set ( )
    {
        return this.timeout_s_ > 0;
    }


    /***************************************************************************

        Returns:
            true if "insecure" SSL downloads are enabled

    ***************************************************************************/

    public bool ssl_insecure_set ( )
    {
        return this.ssl_insecure_;
    }
}

