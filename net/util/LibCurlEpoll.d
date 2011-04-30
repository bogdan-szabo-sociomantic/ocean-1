// Note: very basic, just checked in so it's in source control.

module ocean.net.util.LibCurlEpoll;

private import ocean.core.Array;
private import ocean.core.ArrayMap;
private import ocean.core.ObjectPool;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.net.util.c.multi;
private import ocean.net.util.c.curl;

private import tango.io.selector.EpollSelector;

private import tango.time.Time: TimeSpan;

private import Integer = tango.text.convert.Integer;

private import tango.util.log.Trace;



//TODO: this should basically be a class which extends LibCurl. ???

class CurlConnection : ISelectable
{
    public alias void delegate ( char[] url, char[] data ) Callback;

    private Callback receiver;
    private Callback finalizer;

    char[] url;
    char[] received;

    CURL curl_handle;

    Handle fd;

    Handle fileHandle ( )
    {
        return this.fd;
    }

    void read ( char[] url, Callback finalizer, Callback receiver = null )
    in
    {
        assert(url[$-1] == '\0', "url must be null terminated (C style)");
    }
    body
    {
        this.url.copy(url);

        this.finalizer = finalizer;
        this.receiver = receiver;

        this.received.length = 0;

        this.curl_handle = curl_easy_init();
        assert(this.curl_handle);

        Trace.formatln("New curl easy handle {:x}", this.curl_handle);

        curl_easy_setopt(this.curl_handle, CURLoption.URL, url.ptr);
        curl_easy_setopt(this.curl_handle, CURLoption.WRITEFUNCTION, &write_callback);
        curl_easy_setopt(this.curl_handle, CURLoption.WRITEDATA, cast(void*)this);
    }

    public void receive ( char[] data )
    {
        this.received.append(data);

        if ( this.receiver )
        {
            this.receiver(this.url, data);
        }
    }

    public void finalize ( )
    {
        if ( this.finalizer )
        {
            this.finalizer(this.url, this.received);
        }

        this.clear();
    }

    public void clear ( )
    {
        // TODO: curl_reset ?
    }
    
    static extern ( C )
    {
        size_t write_callback ( char* ptr, size_t size, size_t nmemb, void* userp )
        {
            size_t len = size * nmemb;

            try
            {
                auto curl_obj = cast(CurlConnection)userp;
                curl_obj.receive(ptr[0..len]);
            }
            catch ( Exception e )
            {
                Trace.formatln("Error in write_callback: {}", e.msg);
            }

            return len;
        }
    }
}


class CurlMulti
{
    CURLM multi_handle;

    alias ArrayMap!(CurlConnection, CURL) ConnectionMap;
    ConnectionMap connection_map;

    alias ObjectPool!(CurlConnection) ConnectionPool;
    ConnectionPool connection_pool;

    EpollSelector epoll;

    long timeout_ms;

    public this ( )
    {
        this.connection_pool = new ConnectionPool;
        this.connection_map = new ConnectionMap;

        this.epoll = new EpollSelector;
        this.epoll.open();

        this.multi_handle = curl_multi_init();
        assert(this.multi_handle);

        curl_multi_setopt(this.multi_handle, CURLMoption.SOCKETFUNCTION, &socket_callback);
        curl_multi_setopt(this.multi_handle, CURLMoption.SOCKETDATA, cast(void*)this);
        curl_multi_setopt(this.multi_handle, CURLMoption.TIMERFUNCTION, &timer_callback);
        curl_multi_setopt(this.multi_handle, CURLMoption.TIMERDATA, cast(void*)this);

        Trace.formatln("CurlMulti object pointer = {:x}", cast(void*)this);
    }


    public void read ( char[] url, CurlConnection.Callback finalizer, CurlConnection.Callback receiver = null )
    {
        auto conn = this.connection_pool.get();

        conn.read(url, finalizer, receiver);

        this.connection_map.put(conn.curl_handle, cast(CurlConnection)conn);
        Trace.formatln("New connection: handle = {}", conn.curl_handle);

        curl_multi_add_handle(this.multi_handle, conn.curl_handle);
    }


    public CurlConnection* getConnection ( CURL curl_handle )
    {
//        Trace.formatln("Searching for {:x}", curl_handle);
//        Trace.formatln("Active connections:");
//        foreach ( k, v; this.connection_map )
//        {
//            Trace.formatln("   {:x}: {}", k, v);
//        }
        return curl_handle in this.connection_map;
    }


    public void eventLoop ( )
    {
        int running_handles;

        // This shouldn't be necessary, apparently, but it doesn't work otherwise.
        // It works without it if the timeout callback receives an int rather than a long
//        curl_multi_socket_action(this.multi_handle, CURL_SOCKET_TIMEOUT, 0, &running_handles);

        do
        {
            // nfds = number of file descriptors with events
            TimeSpan timeout = TimeSpan.fromMillis(this.timeout_ms);
//            Trace.formatln("entering epoll_wait with timeout of {}ms", this.timeout_ms);
            auto nfds = this.epoll.select(timeout);
//            Trace.formatln("epoll selected {} fds", nfds);

            if ( nfds == 0 )
            {
//                Trace.formatln("curl_multi_socket_action - CURL_SOCKET_TIMEOUT");
                curl_multi_socket_action(this.multi_handle, CURL_SOCKET_TIMEOUT, 0, &running_handles);
            }
            else
            {
                foreach ( key; this.epoll.selectedSet() )
                {
                    auto fd = key.conduit.fileHandle;

                    Event events = cast(Event)key.events;
                    int mask = 0;

//                    Trace.formatln("Handling key {} : {}", fd, events);

                    if ( events & Event.Read )      mask |= CURL_CSELECT_IN;
                    if ( events & Event.Write )     mask |= CURL_CSELECT_OUT;
                    if ( events & Event.Error )     mask |= CURL_CSELECT_ERR;
                    if ( events & Event.Hangup )    mask |= CURL_CSELECT_ERR;

//                    Trace.formatln("curl_multi_socket_action socket {}", fd);
                    curl_multi_socket_action(this.multi_handle, cast(curl_socket_t)fd, mask, &running_handles);
                }
            }
        }
        while ( running_handles > 0 );

        Trace.formatln("Event loop end ---------------------------------------------");

        foreach ( curl_handle, conn; this.connection_map )
        {
            conn.finalize();
        }
    }


    private void finalize ( CurlConnection conn )
    {
        this.connection_pool.recycle(conn);
        this.connection_map.remove(conn.curl_handle);
        conn.finalize();

        // do this last as it can throw an exception
        this.epoll.unregister(conn);
    }


    static extern ( C )
    {
        // TODO: it seems like I should ignore the top 32 bits of ms...
        // maybe have a look in the libcurl source code to see if there's any notes on this

        // changing it from a long to an int makes it work... very weird

        // Called by curl_multi_socket_action

        int timer_callback ( CURLM multi, int ms, void* userp )
        {
            auto multi_obj = cast(CurlMulti)userp;
            assert(multi == multi_obj.multi_handle);

//            Trace.formatln("Timeout CurlMulti object pointer = {:x}", userp);

//            Trace.formatln("Timer callback: {}ms ({:x})", ms, ms);
            multi_obj.timeout_ms = ms;

            return 0; // obligatory
        }

        
        // Called by curl_multi_socket_action

        int socket_callback ( CURL curl_handle, curl_socket_t socket_fd, int action, void* userp, void* socketp )
        {
//            Trace.formatln("Socket callback");

            auto multi_obj = cast(CurlMulti)userp;
//            Trace.formatln("Socket CurlMulti object pointer = {:x}", userp);

            auto conn = multi_obj.getConnection(curl_handle);
            assert(conn);
            conn.fd = cast(ISelectable.Handle)socket_fd;

//            conduit.fd = cast(ISelectable.Handle)socket_fd;

            if( action == CURL_POLL_REMOVE )
            {
                try
                {
//                    multi_obj.epoll.unregister(*conn);
                    multi_obj.finalize(*conn);
                }
                catch ( Exception e )
                {
                    Trace.formatln("Epoll unregistration error: {}", e.msg);
                }

//                conn.finalize();

                // TODO: recycle connection into pool & remove from map
            }
            else
            {
  //              Trace.formatln("add/mod socket {}, action {}", socket_fd, action);

                Event events;

                if ( action == CURL_POLL_IN || action == CURL_POLL_INOUT )
                    events |= Event.Read;
                if ( action == CURL_POLL_OUT || action == CURL_POLL_INOUT )
                    events |= Event.Write;

                try
                {
                    multi_obj.epoll.register(*conn, events);
                }
                catch ( Exception e )
                {
                    Trace.formatln("Epoll registration error: {}", e.msg);
                }
            }

//            Trace.formatln("Socket callback done");
            return 0; // obligatory
        }
    }
}



