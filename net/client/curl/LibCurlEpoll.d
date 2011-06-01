/*******************************************************************************

    Parallel asynchronous file download with libcurl and epoll.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Uses the libcurl multi socket interface
    (http://curl.haxx.se/libcurl/c/curl_multi_socket_action.html).

    Link with:
        -L/usr/lib/libcurl.so    

    Note about timeouts: there is some conflict between the libcurl managed
    connection timeouts and the timeouts in our epoll selector. The recommended
    way of using libcurl's socket interface is to allow it to completely manage
    connection timeouts. However, it does not simply set a timeout value for a
    connection at startup, it actually always sets a 1ms timeout for a new
    connection, then when that 1ms times out sets the correct timeout value for
    the connection. This behaviour is incompatible with our select dispatcher,
    which automatically unregisters timed out clients. So this module ignores
    the libcurl specified timeouts, and relies on our own timeouts, as defined
    in ISelectClient. This behaviour is safe, as when a connection times out,
    its timeout() method is called, which in this case calls
    curl_multi_remove_handle(), ensuring that libcurl does not think the
    connection is still active. On the other hand, if libcurl cancels a
    connection (for whatever reason), this will be handled correctly in the
    event loop, as the connection's file descriptor will now be invalid, thus
    the client will be unregistered.

*******************************************************************************/

module ocean.net.client.curl.LibCurlEpoll;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;
private import ocean.core.ArrayMap;
private import ocean.core.ObjectPool;
private import ocean.core.SmartEnum;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.net.client.curl.c.multi;
private import ocean.net.client.curl.c.curl;

private import tango.io.selector.SelectorException;

private import tango.time.Time: TimeSpan;

private import Integer = tango.text.convert.Integer;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Curl connection class -- manages a single download.

*******************************************************************************/

// TODO: this would be nicer if it was dervied from LibCurl, and contained an
// ISelectClient instance.

private class CurlConnection : ISelectClient, ISelectable
{
    /***************************************************************************

        Alias for a Handle (fd)

    ***************************************************************************/

    public alias ISelectable.Handle Handle;


    /***************************************************************************

        Receiver delegate & alias
    
    ***************************************************************************/

    public alias void delegate ( char[] url, char[] data ) Receiver;

    private Receiver receiver_dg;


    /***************************************************************************

        Finalizer status enum

    ***************************************************************************/

    public mixin(AutoSmartEnum!("FinalizeState", ubyte,
        "Success",
        "TimedOut",
        "Error"
    ));


    /***************************************************************************

        Finalizer delegate & alias

    ***************************************************************************/

    public alias void delegate ( char[] url, FinalizeState.BaseType state ) Finalizer;

    private Finalizer finalizer_dg;


    /***************************************************************************

        Handler delegate & alias

    ***************************************************************************/

    public alias void delegate ( typeof(this) conn, Event events ) Handler;

    private Handler handler_dg;


    /***************************************************************************

        Abort delegate & alias
    
    ***************************************************************************/
    
    public alias void delegate ( typeof(this) conn ) MultiCleaner;
    
    private MultiCleaner multi_cleaner_dg;


    /***************************************************************************

        Curl easy handle for this connection

    ***************************************************************************/

    private CURL curl_handle;


    /***************************************************************************

        File descriptor for this connection (registered with epoll)

    ***************************************************************************/

    private Handle fd;


    /***************************************************************************

        Epoll events which this connection is waiting on

    ***************************************************************************/

    private Event events_;


    /***************************************************************************

        Url being downloaded

    ***************************************************************************/

    private char[] url;


    /***************************************************************************

        Transfer state (defaults to success, unless an error or timeout occurs)

    ***************************************************************************/

    private FinalizeState.BaseType state;


    /***************************************************************************

        Flag set when this client should be unregistered

    ***************************************************************************/

    public bool unregister;


    /***************************************************************************

        Flag set when this client has been finalized, to avoid calling the
        finalizer twice

    ***************************************************************************/

    public bool finalized;


    /***************************************************************************

        Constructor.

        This instance is passed to the super class as an ISelectable.

        Params:
            handler_dg = delegate to be called when this connection fires in
                epoll

    ***************************************************************************/

    public this ( Handler handler_dg, MultiCleaner multi_cleaner_dg )
    in
    {
        assert(handler_dg !is null, typeof(this).stringof ~ ".ctor: handler delegate must not be null");
        assert(multi_cleaner_dg !is null, typeof(this).stringof ~ ".ctor: multi cleaner delegate must not be null");
    }
    body
    {
        this.handler_dg = handler_dg;
        this.multi_cleaner_dg = multi_cleaner_dg;

        super(this);
    }


    /***************************************************************************

        Destructor. Cleans up the curl handle.

    ***************************************************************************/

    ~this ( )
    {
        if ( this.curl_handle !is null )
        {
            curl_easy_cleanup(this.curl_handle);
        }
    }


    /***************************************************************************

        Initiates this connection to download a url.

        Params:
            url = url to download
            receiver_dg = delegate to be called when data is received
            finalizer_dg = delegate to be called when the download has finished
                (this may be due to success or a timeout)

    ***************************************************************************/

    public void download ( char[] url, Receiver receiver_dg, Finalizer finalizer_dg )
    in
    {
        assert(url[$-1] == '\0', typeof(this).stringof ~ ".read: url must be null terminated (C style)");
        assert(receiver_dg !is null, typeof(this).stringof ~ ".read: receiver delegate must not be null");
    }
    body
    {
        this.state = FinalizeState.Success;
        this.unregister = false;
        this.finalized = false;

        this.url.copy(url);

        this.receiver_dg = receiver_dg;
        this.finalizer_dg = finalizer_dg;

        if ( this.curl_handle is null )
        {
            this.curl_handle = curl_easy_init();
        }
        else
        {
            curl_easy_reset(this.curl_handle);
        }
        assert(this.curl_handle);

        curl_easy_setopt(this.curl_handle, CURLoption.URL, url.ptr);
        curl_easy_setopt(this.curl_handle, CURLoption.WRITEFUNCTION, &writeCallback);
        curl_easy_setopt(this.curl_handle, CURLoption.WRITEDATA, cast(void*)this);

        // TODO: more curl easy setup options (copy from LibCurl module)
        // could this class actually be an extended version of that?
    }


    /***************************************************************************

        ISelectClient method.

        Returns:
            the events with which this connection is registered to epoll

    ***************************************************************************/

    public Event events ( )
    {
        return this.events_;
    }


    /***************************************************************************

        Sets the events with which this connection is registered to epoll.

        Params:
            events_ = the events with which this connection is registered to
                epoll

    ***************************************************************************/

    public void setEvents ( Event events_ )
    {
        this.events_ = events_;
    }


    /***************************************************************************

        Returns:
            the curl handle for this connection
    
    ***************************************************************************/
    
    public CURL curlHandle ( )
    {
        return this.curl_handle;
    }


    /***************************************************************************

        ISelectable interface method.
    
        Returns:
            this connection's file descriptor
    
    ***************************************************************************/
    
    Handle fileHandle ( )
    {
        return this.fd;
    }


    /***************************************************************************

        Sets the file descriptor this connection uses.

        Params:
            fd = file descriptor

    ***************************************************************************/

    public void setFileHandle ( curl_socket_t fd )
    {
        this.fd = cast(Handle)fd;
    }


    /***************************************************************************

        ISelectClient method. Called when one of this connection's registered
        epoll events fires.

        Params:
            events = events which fired

        Returns:
            Always true, to stay registered with epoll. (The epoll events are
            unregistered by hand in LibCurlEpoll.socket_callback.)

    ***************************************************************************/

    public bool handle ( Event events )
    in
    {
        assert(this.handler_dg !is null, typeof(this).stringof ~ ".handle: handler delegate not set");
    }
    body
    {
        if ( this.unregister )
        {
            return false;
        }
        else
        {
            this.handler_dg(this, events);

            return !this.unregister;
        }
    }


    /***************************************************************************

        ISelectClient method override. Called when an epoll timeout occurs for
        this connection. Aborts the connection.
    
    ***************************************************************************/

    override public void timeout ( )
    {
        this.state = FinalizeState.TimedOut;
        this.multi_cleaner_dg(this);
    }


    /***************************************************************************

        ISelectClient method override. Called when an error occurs during the
        handling of an event for this connection. Aborts the connection.

        Params:
            exception: Exception thrown by handle()
            event:     Seletor event while exception was caught

    ***************************************************************************/

    override public void error ( Exception exception, Event event )
    {
        this.state = FinalizeState.Error;
        this.multi_cleaner_dg(this);
    }


    /***************************************************************************

        Returns an identifier string of this instance. (Note: not memory safe,
        but only exists in debug builds anyway, so no worries.)

        Returns:
             identifier string of this instance

    ***************************************************************************/

    debug ( ISelectClient )
    {
        public char[] id ( )
        {
            return typeof(this).stringof ~ " " ~ this.url;
        }
    }


    /***************************************************************************

        Calls the finalizer delegate (if it exists) with the specified status.

        Params:
             status

    ***************************************************************************/

    public void finalize ( )
    {
        // Checks if the connection has really finished, if not it must be an
        // error.
        uint code;
        curl_easy_getinfo(this.curl_handle, CurlInfo.CURLINFO_RESPONSE_CODE, &code);
        if ( code == 0 )
        {
            this.state = FinalizeState.Error;
        }

        if ( !this.finalized && this.finalizer_dg !is null )
        {
            this.finalizer_dg(this.url, this.state);
        }
        this.multi_cleaner_dg(this);

        this.finalized = true;
    }


    /***************************************************************************

        Called when data is received, passing it on to the receiver delegate.

        Params:
            data = data received

    ***************************************************************************/

    private void receive ( char[] data )
    in
    {
        assert(this.receiver_dg !is null, typeof(this).stringof ~ ".receive: receiver delegate not set");
    }
    body
    {
        this.receiver_dg(this.url, data);
    }


    static extern ( C )
    {
        /***********************************************************************

            Libcurl write callback. Called when data is received. Passes it on
            to the receiving connection object.

            Params:
                ptr = pointer to buffer containing received data
                size = number of bytes in one member of the data buffer
                nmemb = number of members in data buffer
                userp = user-defined pointer, in this case a reference to a
                    CurlConnection instance

            Returns:
                number of bytes consumed

        ***********************************************************************/

        private size_t writeCallback ( char* ptr, size_t size, size_t nmemb, void* userp )
        {
            size_t len = size * nmemb;

            try
            {
                auto curl_obj = cast(CurlConnection)userp;
                curl_obj.receive(ptr[0..len]);
            }
            catch ( Exception e )
            {
                debug Trace.formatln("Error in write_callback: {}", e.msg);
            }

            return len;
        }
    }
}



/*******************************************************************************

    Curl multi connection class -- manages a set of downloads

*******************************************************************************/

public class LibCurlEpoll
{
    /***************************************************************************

        Curl multi handle

    ***************************************************************************/

    private CURLM multi_handle;


    /***************************************************************************

        Epoll selector instance, passed as a reference to the constructor.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;


    /***************************************************************************

        Connection pool & alias

    ***************************************************************************/

    private alias ObjectPool!(CurlConnection, CurlConnection.Handler, CurlConnection.MultiCleaner) ConnectionPool;
    private ConnectionPool connection_pool;


    /***************************************************************************

        Connection map & alias. (Maps from a libcurl easy handle to a connection
        instancei n the pool.)

    ***************************************************************************/

    private alias ArrayMap!(CurlConnection, CURL) ConnectionMap;
    private ConnectionMap connection_map;


    /***************************************************************************

        Urls map & alias. (Maintains a list of the urls which are being
        downloaded.)

    ***************************************************************************/

    private alias Set!(char[]) UrlsSet;
    private UrlsSet urls_set;


    /***************************************************************************

        Finalizer delegate to be called when a connection finishes.

    ***************************************************************************/

    private CurlConnection.Finalizer finalizer_dg;


    /***************************************************************************

        User-specified connection timeout in millseconds. (Defaults to no
        timeout.) The smaller of the two (user- vs curl-specified) timeouts is
        used.

    ***************************************************************************/

    private int timeout_ms = -1;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll select dispatcher to use

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll )
    {
        this.epoll = epoll;

        this.connection_pool = new ConnectionPool(&this.handleConnection, &this.cleanupConnection);
        this.connection_map = new ConnectionMap;
        this.urls_set = new UrlsSet;

        this.multi_handle = curl_multi_init();
        assert(this.multi_handle);

        curl_multi_setopt(this.multi_handle, CURLMoption.SOCKETFUNCTION, &socket_callback);
        curl_multi_setopt(this.multi_handle, CURLMoption.SOCKETDATA, cast(void*)this);
    }


    /***************************************************************************

        Destructor. Cleans up the curl handle.
    
    ***************************************************************************/
    
    ~this ( )
    {
        if ( this.multi_handle !is null )
        {
            curl_multi_cleanup(this.multi_handle);
        }
    }


    /***************************************************************************

        Requests a url to be downloaded.

        Params:
            url = url to download
            receiver_dg = delegate to be called when data is received
            finalizer_dg = delegate to be called when the download has finished
                (this may be due to success or a timeout)

        Returns:
            true on success, or false if the requested url is already being
            downloaded.

    ***************************************************************************/

    public bool download ( char[] url, CurlConnection.Receiver receiver_dg, CurlConnection.Finalizer finalizer_dg,
            void delegate ( CurlConnection connection ) setup_dg = null )
    {
        if ( url in this.urls_set )
        {
            return false;
        }
        else
        {
            auto conn = this.connection_pool.get();

            conn.download(url, receiver_dg, finalizer_dg);
            if ( setup_dg !is null )
            {
                setup_dg(conn);
            }

            this.updateConnectionTimeout(conn);

            this.connection_map.put(conn.curlHandle, cast(CurlConnection)conn);
            this.urls_set.put(url);

            curl_multi_add_handle(this.multi_handle, conn.curlHandle);

            // Calling socket action will cause the epoll events for this connection to be registered
            this.socketAction(CURL_SOCKET_TIMEOUT, 0);

            // TODO: There's a blocking DNS lookup when a new connection is added and
            // multi_socket_action is called. If this becomes problematic then
            // we should try setting CURLOPT_DNS_CACHE_TIMEOUT to a higher value
            // or compile libcurl with the c_ares asyn DNS library.

            return true;
        }
    }


    /***************************************************************************

        Returns:
            the number of active connections
    
    ***************************************************************************/

    public size_t activeConnections ( )
    {
        return this.urls_set.length;
    }


    /***************************************************************************

        Checks whether a url is already downloading.

        Params:
            url = url to check for

        Returns:
            true if the url is already downloading

    ***************************************************************************/

    public bool downloading ( char[] url )
    {
        return url in this.urls_set;
    }


    /***************************************************************************

        foreach iterator over the currently downloading urls.

    ***************************************************************************/

    public int opApply ( int delegate ( ref char[] url ) dg )
    {
        int res;

        foreach ( url; this.urls_set )
        {
            res = dg(url);
            if ( !res ) break;
        }

        return res;
    }


    /***************************************************************************

        Sets the timeout for all current and future connections.

        Params:
            ms = milliseconds timeout to set (must be >= 0)

    ***************************************************************************/

    public void setConnectionTimeout ( int ms )
    in
    {
        assert(ms >= 0, typeof(this).stringof ~ ".setConnectionsTimeout: negative timeout values have no meaning");
    }
    body
    {
        this.timeout_ms = ms;
        this.updateConnectionsTimeout_();
    }


    /***************************************************************************

        Disables the timeout for all current and future connections.

    ***************************************************************************/

    public void disableConnectionTimeout ( )
    {
        this.timeout_ms = -1;
        this.updateConnectionsTimeout_();
    }


    /***************************************************************************

        Sets the timeout for all current and future connections.

        Params:
            ms = milliseconds timeout to set

    ***************************************************************************/

    private void updateConnectionsTimeout_ ( )
    {
        foreach ( conn; this.connection_pool )
        {
            this.updateConnectionTimeout(conn);
        }
    }


    /***************************************************************************

        Sets the timeout for a specific connection. The smaller of the curl-
        specified and the user-specified timeouts is used.

        Params:
            conn = connection to set timeout of
    
    ***************************************************************************/

    private void updateConnectionTimeout ( CurlConnection conn )
    {

        if ( this.timeout_ms >= 0 )
        {
            conn.setTimeout(this.timeout_ms);
        }
        else
        {
            conn.disableTimeout();
        }
    }


    /***************************************************************************

        Gets the connection corresponding to a specific curl easy handle.

        Params:
            curl_handle = curl handle to get connection for

        Returns:
            pointer to connection corresponding to curl_handle, can be null

    ***************************************************************************/

    private CurlConnection* getConnection ( CURL curl_handle )
    {
        return curl_handle in this.connection_map;
    }


    /***************************************************************************

        Handles an event on a curl managed socket.

        Params:
            conn = connection in which event occurred
            events = epoll events which fired

    ***************************************************************************/

    private void handleConnection ( CurlConnection conn, ISelectClient.Event events )
    {
        int mask;
        if ( events & Event.Read )      mask |= CURL_CSELECT_IN;
        if ( events & Event.Write )     mask |= CURL_CSELECT_OUT;
        if ( events & Event.Error )     mask |= CURL_CSELECT_ERR;
        if ( events & Event.Hangup )    mask |= CURL_CSELECT_ERR;

        this.socketAction(cast(curl_socket_t)conn.fileHandle, mask);
    }


    /***************************************************************************

        Aborts the processing of a connection. Called by a connection when an
        error or timeout occurs.

        Params:
            conn = connection to abort
    
    ***************************************************************************/

    private void cleanupConnection ( CurlConnection conn )
    {
        this.urls_set.remove(conn.url);
        curl_multi_remove_handle(this.multi_handle, conn.curlHandle);
    }


    /***************************************************************************

        Adds a new connection to epoll, or modifies an already registered
        connection. Called by socketCallback().

        Params:
            conn = connection to add / modify

    ***************************************************************************/

    private void addModifyConnection ( CurlConnection conn )
    {
        this.epoll.register(conn);
    }


    /***************************************************************************

        Removes a connection from epoll, and the various internal maps. The
        connection's finalizer delegate is also called. Called by
        socketCallback().

        Params:
            conn = connection to remove

    ***************************************************************************/

    private void removeConnection ( CurlConnection conn )
    {
        this.connection_pool.recycle(conn);
        this.connection_map.remove(conn.curl_handle);
        this.urls_set.remove(conn.url);

        conn.unregister = true;

        // ensure that the client is removed after this select cycle
        // (otherwise dead fds can remain registered with epoll)
         this.epoll.unregisterAfterSelect(conn);
    }


    /***************************************************************************

        Informs curl of action on a socket it is managing.

        Params:
            fd = file descriptor of socket on which action occurred
            mask = events which occurred

    ***************************************************************************/

    private void socketAction ( curl_socket_t fd, int mask )
    {
        int running_handles;
        curl_multi_socket_action(this.multi_handle, fd, mask, &running_handles);
    }


    static extern ( C )
    {
        /***********************************************************************

            At the request of curl_multi_socket_action, performs various actions
            on a connection.

            Params:
                curl_handle = connection's curl easy handle
                fd = connection's file descriptor
                action = action required
                userp = user defined pointer (reference to a LibCurlEpoll
                    instance, in this case)
                socketp = unused

            Returns:
                0 (obligatory)

        ***********************************************************************/

        int socket_callback ( CURL curl_handle, curl_socket_t socket_fd, int action, void* userp, void* socketp )
        {
            auto multi_obj = cast(LibCurlEpoll)userp;

            auto conn = multi_obj.getConnection(curl_handle);
            if ( conn )
            {
                conn.setFileHandle(socket_fd);

                if ( action == CURL_POLL_REMOVE )
                {
                    try
                    {
                        multi_obj.removeConnection(*conn);
                    }
                    catch ( Exception e )
                    {
                        debug Trace.formatln("Epoll unregistration error: {}", e.msg);
                    }
                }
                else
                {
                    ISelectClient.Event events;

                    if ( action == CURL_POLL_IN || action == CURL_POLL_INOUT )
                        events |= Event.Read;
                    if ( action == CURL_POLL_OUT || action == CURL_POLL_INOUT )
                        events |= Event.Write;

                    conn.setEvents(events);

                    try
                    {
                        multi_obj.addModifyConnection(*conn);
                    }
                    catch ( Exception e )
                    {
                        debug Trace.formatln("Epoll registration error: {}", e.msg);
                    }
                }
            }
            else
            {
                debug Trace.formatln("ERROR: no conn");
            }

            return 0; // obligatory
        }
    }
}

