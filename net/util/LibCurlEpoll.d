module ocean.net.util.LibCurlEpoll;

private import ocean.core.Array;
private import ocean.core.ArrayMap;
private import ocean.core.ObjectPool;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.model.ISelectClient;

private import ocean.net.util.c.multi;
private import ocean.net.util.c.curl;

private import tango.io.selector.SelectorException;
//private import tango.io.selector.EpollSelector;

private import tango.time.Time: TimeSpan;

private import Integer = tango.text.convert.Integer;

private import tango.util.log.Trace;



//TODO: this should basically be a class which extends LibCurl. ???

class CurlConnection : ISelectClient // TODO: does it need to be Advanced?
{
    private class Conduit : ISelectable
    {
        Handle fd;

        Handle fileHandle ( )
        {
            return this.fd;
        }
    }

    private Conduit conduit;

    public void setHandle ( curl_socket_t fd )
    {
        this.conduit.fd = cast(Handle)fd;
    }
    
    private Event events_;

    public Event events ( )
    {
        return this.events_;
    }

    public void setEvents ( Event events_ )
    {
        this.events_ = events_;
    }

    public bool handle ( Event events )
    {
        auto fd = this.conduit.fileHandle;

        int mask = 0;

        Trace.formatln("Handling key {} : {}", fd, events);

        if ( events & Event.Read )      mask |= CURL_CSELECT_IN;
        if ( events & Event.Write )     mask |= CURL_CSELECT_OUT;
        if ( events & Event.Error )     mask |= CURL_CSELECT_ERR;
        if ( events & Event.Hangup )    mask |= CURL_CSELECT_ERR;

//        Trace.formatln("curl_multi_socket_action socket {}", fd);
        this.curl_multi.socketAction(cast(curl_socket_t)fd, mask);

        return true;
    }

    CurlMulti curl_multi;

    public this ( CurlMulti curl_multi )
    {
        this.curl_multi = curl_multi;

        this.conduit = new Conduit;

        super(this.conduit);
    }
    
    public alias void delegate ( char[] url, char[] data ) Callback;

    private Callback receiver;
    private Callback finalizer;

    char[] url;
    char[] received;

    CURL curl_handle;

    alias ISelectable.Handle Handle;
    
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

    debug ( ISelectClient )
    {
        public char[] id ( )
        {
            return typeof(this).stringof ~ " " ~ this.url; // TODO: memory bad
        }
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

    alias ObjectPool!(CurlConnection, CurlMulti) ConnectionPool;
    ConnectionPool connection_pool;

    EpollSelectDispatcher epoll;

    int timeout_ms;

    public this ( EpollSelectDispatcher epoll )
    {
//        this.epoll = new EpollSelector;
//        this.epoll.open();
        this.epoll = epoll;

        this.connection_pool = new ConnectionPool(this);
        this.connection_map = new ConnectionMap;

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
        return curl_handle in this.connection_map;
    }


    private int running_handles;

    public void eventLoop ( )
    {
        this.running_handles = 0;

        do
        {
            this.epoll.timeout(this.timeout_ms);
            auto timeout = !this.epoll.eventLoop;

            if ( timeout )
            {
                this.socketAction(CURL_SOCKET_TIMEOUT, 0);
            }
        }
        while ( this.running_handles > 0 );

        Trace.formatln("Event loop end ---------------------------------------------");

        assert(this.connection_map.length == 0);
    }

    public void socketAction ( curl_socket_t fd, int mask )
    {
        Trace.formatln("Socket action {} : {}", fd, mask);
        curl_multi_socket_action(this.multi_handle, fd, mask, &running_handles);
    }


    private void addModifyConnection ( CurlConnection conn )
    {
        Trace.formatln("Add/modify {}", conn.conduit.fileHandle);
        this.epoll.register(conn);
    }


    private void finalizeConnection ( CurlConnection conn )
    {
        Trace.formatln("Finalize {}", conn.conduit.fileHandle);
        this.connection_pool.recycle(conn);
        this.connection_map.remove(conn.curl_handle);
        conn.finalize();

        // do this last as it can throw an exception
        this.epoll.unregister(conn);
    }


    static extern ( C )
    {
        // Called by curl_multi_socket_action

        int timer_callback ( CURLM multi, int ms, void* userp )
        {
            Trace.formatln("timer_callback: {}ms", ms);
            scope ( failure ) Trace.formatln("ERROR: in timer_callback");

            auto multi_obj = cast(CurlMulti)userp;
            if ( multi == multi_obj.multi_handle )
            {
                multi_obj.timeout_ms = ms;
            }

            return 0; // obligatory
        }

        
        // Called by curl_multi_socket_action when something needs doing with a socket

        int socket_callback ( CURL curl_handle, curl_socket_t socket_fd, int action, void* userp, void* socketp )
        {
            Trace.formatln("socket_callback");
            scope ( failure ) Trace.formatln("ERROR: in socket_callback");
            
            auto multi_obj = cast(CurlMulti)userp;
            Trace.formatln("Socket callback: CurlMulti object pointer = {:x}", userp);

            auto conn = multi_obj.getConnection(curl_handle);
            if ( conn )
            {
                conn.setHandle(socket_fd);

                if( action == CURL_POLL_REMOVE )
                {
                    try
                    {
                        Trace.formatln("File descriptor {} has finished", socket_fd);
                        multi_obj.finalizeConnection(*conn);
                    }
                    catch ( UnregisteredConduitException e )
                    {
                        Trace.formatln("Epoll unregistration error: fd not registered - {}", e.msg);
                    }
                    catch ( SelectorException e )
                    {
                        Trace.formatln("Epoll unregistration error: {}", e.msg);
                    }
                    catch ( Exception e )
                    {
                        Trace.formatln("Epoll unregistration error: {}", e.msg);
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
                        Trace.formatln("Epoll registration error: {}", e.msg);
                    }
                }
            }
            else
            {
                Trace.formatln("ERROR: no conn");
            }

            return 0; // obligatory
        }
    }
}



