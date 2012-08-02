/*******************************************************************************

    Parallel asynchronous file download with libcurl and epoll.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        June 2011: Initial release

    authors:        Gavin Norman

    Uses the libcurl multi socket interface
    (http://curl.haxx.se/libcurl/c/curl_multi_socket_action.html).

    Link with:
    
    ---
    
        -L/usr/lib/libcurl.so    
        -L-lgblib-2.0

    ---

    Usage example:

    ---
    
        TODO
    
    ---

*******************************************************************************/

module ocean.net.client.curl.LibCurlEpoll;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.EpollSelectDispatcher;
private import ocean.io.select.event.TimerEvent;
private import ocean.io.select.event.SelectEvent;

private import ocean.net.client.curl.c.multi;
private import ocean.net.client.curl.c.curl;

private import ocean.sys.SignalHandler;

private import ocean.net.util.UrlEncoder;

private import ocean.util.OceanException;

private import ocean.util.container.queue.NotifyingQueue;

private import tango.stdc.string : strlen;

debug private import ocean.util.log.Trace;



/*******************************************************************************

    Global curl object which allows multiple urls to be downloaded in parallel.

    Note: this class does not have a destructor, and thus does not correctly
    shut down the libcurl multi stack. The shutdown is problematic, as a strict
    order of cleanup must be enforced (first remove easy handles from the multi
    stack, then cleanup the easy handles, then cleanup the multi stack). It is
    far from trivial to implement this procedure using D's destructor mechanism.
    In practice, unless we end up creating and destroying instances of this
    class as part of an application's routine operation, this is harmless.

*******************************************************************************/

public class LibCurlEpoll
{
    /***************************************************************************

        Static constructor, registers a handler for SIGPIPE. This signal needs
        to be handled because we experienced it while downloading urls via SSL.

    ***************************************************************************/

    static this ( )
    {
        with ( SignalHandler )
        {
            register(Signals.SIGPIPE, &sigpipeHandler);
        }
    }


    /***************************************************************************

        SIGPIPE handler, simply returns false to ensure that the default handler
        is not invoked (which would break the application).

    ***************************************************************************/

    static private bool sigpipeHandler ( int signal )
    {
        return false;
    }


    /***************************************************************************

        Connection interface. When a connection is about to start processing, an
        instance of this interface (implemented by the CurlConnection class,
        below) is passed to the initializer delegate specified in a call to the
        download() method.

        The interface provides various methods to set up the curl options for
        the connection, in addition to a method to cancel the connection.

    ***************************************************************************/

    public interface IConnection
    {
        public char[] encodeUrl ( );

        public void verbose ( );

        public void authorize ( char[] user, char[] passwd );

        public void acceptNoEncoding ( );
        public void acceptAnyEncoding ( );
        public void acceptZlibEncoding ( );
        public void acceptGzipEncoding ( );

        public void ignoreSSLHost ( );

        public void allowRedirects( );

        public void cancel ( );
    }


    /***************************************************************************

        Alias for a curl result code.

    ***************************************************************************/

    public alias .CURLcode Result;


    /***************************************************************************

        Static function which gets the description string corresponding to a
        result code.

        Params:
            result = code
            str = buffer to receive description

        Returns:
            description of result code

    ***************************************************************************/

    static public char[] resultString ( Result result, ref char[] str )
    {
        auto C_str = curl_easy_strerror(result);
        auto len = strlen(C_str);
        str.copy(C_str[0..len]);

        return str;
    }


    /***************************************************************************

        Info about a single request which is stored in the request queue inside
        the LibCurlEpoll instance.

    ***************************************************************************/

    private struct CurlRequest
    {
        /***********************************************************************
        
            Url being downloaded.
        
        ***********************************************************************/
        
        public char[] url;
        
        
        /***********************************************************************

            Delegate called when transfer begins. (The callback is stored as a
            byte array as the struct serializer doesn't currently support
            serializing delegates.)

        ***********************************************************************/

        private alias void delegate ( void* context, IConnection connection ) Initializer;

        private ubyte[Initializer.sizeof] initializer_;


        /***********************************************************************
        
            Delegate which receives data. (The callback is stored as a byte
            array as the struct serializer doesn't currently support serializing
            delegates.) 
        
        ***********************************************************************/
        
        public alias void delegate ( void* context, size_t connection, char[] url, char[] data ) Receiver;
        
        private ubyte[Receiver.sizeof] receiver_;
        
        
        /***********************************************************************
        
            Delegate called when transfer finishes. (The callback is stored as a
            byte array as the struct serializer doesn't currently support
            serializing delegates.) 
        
        ***********************************************************************/

        public alias void delegate ( void* context, size_t connection, char[] url, int http_response, CURLcode result ) Finalizer;

        private ubyte[Finalizer.sizeof] finalizer_;


        /***********************************************************************

            User-specified request context.

        ***********************************************************************/
        
        private ubyte[(void*).sizeof] context_;
        
        
        /***********************************************************************
        
            Initializer getter & setter.
    
        ***********************************************************************/

        public void initializer ( Initializer initializer_ )
        {
            this.initializer_[]  = (cast(ubyte*)&initializer_)[0 .. initializer_.sizeof];
        }

        public Initializer initializer ( )
        {
            return *(cast(Initializer*)this.initializer_.ptr);
        }
    
    
        /***********************************************************************
        
            Receiver getter & setter.
        
        ***********************************************************************/
        
        public void receiver ( Receiver receiver_ )
        {
            this.receiver_[]  = (cast(ubyte*)&receiver_)[0 .. receiver_.sizeof];
        }

        public Receiver receiver ( )
        {
            return *(cast(Receiver*)this.receiver_.ptr);
        }
        
        
        /***********************************************************************
        
            Finalizer getter & setter.
        
        ***********************************************************************/
        
        public void finalizer ( Finalizer finalizer_ )
        {
            this.finalizer_[] = (cast(ubyte*)&finalizer_)[0 .. finalizer_.sizeof];
        }
        
        public Finalizer finalizer ( )
        {
            return *(cast(Finalizer*)this.finalizer_.ptr);
        }
        
        
        /***********************************************************************
        
            Context getter & setter.
        
        ***********************************************************************/

        public void context ( void* context_ )
        {
            this.context_[] = (cast(ubyte*)&context_)[0 .. context_.sizeof];
        }

        public void* context ( )
        {
            return *(cast(void**)this.context_.ptr);
        }
    }


    /***************************************************************************

        A single curl connection. Owned and managed by an instance of the outer
        class.

        Note: this class does not have a destructor, and thus does not correctly
        shut down the libcurl easy handle. The shutdown is problematic, as a
        strict order of cleanup must be enforced (first remove easy handles from
        the multi stack, then cleanup the easy handles, then cleanup the multi
        stack). It is far from trivial to implement this procedure using D's
        destructor mechanism. In practice, unless we end up creating and
        destroying instances of this class as part of an application's routine
        operation, this is harmless.

    ***************************************************************************/

    private class CurlConnection : ISelectClient, IConnection, ISelectable
    {
        /***********************************************************************
    
            Curl easy handle.
    
        ***********************************************************************/
    
        public CURL easy;
    
    
        /***********************************************************************
    
            File descriptor of the socket handling this connection. This is set
            by the outer class' curl socket callback function.

        ***********************************************************************/
    
        public curl_socket_t fd;
    
        
        /***********************************************************************
    
            Code for action which connection is waiting on (read / write).
    
        ***********************************************************************/
    
        public int action;


        /***********************************************************************

            Curl code for last result this connection received (usually just
            when the connection finishes). Passed through to the finalizer.

        ***********************************************************************/

        public CURLcode result;


        /***********************************************************************
    
            Event which is registered with the epoll selector and fired when this
            connection is ready to start processing the next request (popped from
            the queue in LibCurlEpoll).
    
        ***********************************************************************/
    
        private SelectEvent conn_ready;
    

        /***********************************************************************
    
            Url currently being processed. (Copied, and with a \0 appended, for C
            compatibility.)
    
        ***********************************************************************/
    
        private char[] url;
    
    
        /***********************************************************************
    
            Delegate to be called when this request receives data.
    
        ***********************************************************************/
    
        private CurlRequest.Receiver receiver;
    
    
        /***********************************************************************

            Delegate to be called when this request has finished. Called both in
            case of error and successful download.

        ***********************************************************************/

        private CurlRequest.Finalizer finalizer;


        /***********************************************************************

            User-specified context for the request.

        ***********************************************************************/

        private void* request_context;


        /***********************************************************************
        
            Flag set to true when the finalizer has been called for the current
            connection. The flag is reset when a new connection begins (in the
            download() method).
        
            This flag is needed because both the epoll error callback and the
            curl socket callback invoke the connection's finalize() method. As
            the socket callback is invoked (via a call to
            curl_multi_socket_action) in the ISelectClient's handle() method,
            and as a result curl can request the finalization of *any*
            connection (not just the one which is being handled), then it is
            possible for error() to also request the finalization of the
            connection. Thus finalization can be requested twice for a single
            connection in a single select cycle. This is rare, but fatal without
            this flag.
        
        ***********************************************************************/

        private bool finalized;


        /***********************************************************************

            Unique numerical id for this connection. Passed to receuiver
            delegates.

        ***********************************************************************/

        private int id_num;

        static private int next_id_num;


        /***********************************************************************

            String buffer used for formatting transfer authorizations.

        ***********************************************************************/

        private char[] auth_string;


        /***********************************************************************

            String buffer used for url percent encoding.

        ***********************************************************************/

        private char[] url_encoding_buffer;


        /***********************************************************************

            Constructor. Creates a curl easy handle which is reused.

        ***********************************************************************/

        this ( )
        {
            this.id_num = next_id_num++;

            this.conn_ready = new SelectEvent(&this.conn_ready_cb);

            this.easy = curl_easy_init();

            super(this);
        }


        /***********************************************************************

            Initiates the downloading of a url.

            Params:
                request = request struct, containing the url to download and the
                    delegates to call upon receiving data

        ***********************************************************************/

        public void download ( CurlRequest* request )
        {
            curl_multi_remove_handle(this.outer.multi, this.easy);
            curl_easy_reset(this.easy);

            this.url.copy(request.url);
            this.receiver = request.receiver;
            this.finalizer = request.finalizer;
            this.request_context = request.context;
            this.finalized = false;
            this.fd = 0;
            this.result = CURLcode.CURLE_OK;

            auto initializer = request.initializer;
            if ( initializer !is null )
            {
                initializer(this.request_context, this);
            }

            this.url.append("\0");
            this.initTransfer();

            curl_multi_add_handle(this.outer.multi, this.easy);
        }


        /***********************************************************************

            Called by the outer class (from the curl socket callback) when this
            connection has finished downloading. The user-specified finalizer is
            called and the client is unregistered from the epoll selector.

        ***********************************************************************/

        public void finished ( )
        {
            this.finalize();

            this.outer.epoll.unregister(this);
        }


        /***********************************************************************

            ISelectable interface method. Lets the epoll selector know which
            file descriptor to watch.

            Returns:
                file descriptor which epoll should watch

        ***********************************************************************/

        public Handle fileHandle ( )
        {
            return cast(Handle)this.fd;
        }


        /***********************************************************************

            ISelectClient method. Called when this connection fires in epoll,
            and notifies libcurl of the events which have occurred.

            Returns:
                always true to stay registered in epoll. The client is only
                unregistered in the finished() method.

        ***********************************************************************/

        public bool handle ( Event events )
        {
            int action;
            if ( events & Event.Read )      action |= CURL_CSELECT_IN;
            if ( events & Event.Write )     action |= CURL_CSELECT_OUT;
            if ( events & Event.Error )     action |= CURL_CSELECT_ERR;
            if ( events & Event.Hangup )    action |= CURL_CSELECT_ERR;

            curl_multi_socket_action(this.outer.multi, cast(curl_socket_t)this.fileHandle, action, &this.outer.still_running);

            if ( this.outer.still_running == 0 )
            {
                this.outer.unregister_timer = true;
                this.outer.epoll.unregister(this.outer.timer);
                this.outer.timer.reset();
            }

            return true; // client is only unregistered from epoll in the finished() method
        }


        /***********************************************************************

            ISelectClient method. Lets epoll know which events should be watched
            for this connection.

            Returns:
                events which epoll should watch for this connection

        ***********************************************************************/

        public Event events ( )
        {
            Event event;
            if ( this.action & CURL_POLL_IN )   event |= Event.Read;
            if ( this.action & CURL_POLL_OUT )  event |= Event.Write;
            return event;
        }


        /***********************************************************************

            ISelectClient method. Called when a connection or handling error
            occurs for this connection.
            
            Params:
                e = exception whic occurred
                ev = event which fired

        ***********************************************************************/

        override protected void error_ ( Exception e, Event ev )
        {
            this.finalize();
        }
    
    
        /***********************************************************************

            ITimeoutClient method. Returns a debug identifier for message
            output.

            Returns:
                identifier for this connection

        ***********************************************************************/

        debug
        {
            public char[] id ( )
            {
                char[1] id_str;
                id_str[0] = '0' + cast(char)this.id_num;
                return typeof(this).stringof ~ " " ~ id_str ~ ": " ~ this.url;
            }
        }
    
    
        /***********************************************************************

            IRequestHandler method. Called when this connection is finalized.
            Registers and triggers the select event, which will cause the next
            request to be popped from the request queue (on the next select
            cycle).

        ***********************************************************************/

        public void notify ( )
        {
            this.outer.epoll.register(this.conn_ready);
            this.conn_ready.trigger();
        }


        /***********************************************************************

            URL encodes the url.

            Returns:
                percent encoded url

        ***********************************************************************/

        public char[] encodeUrl ( )
        {
            scope UrlEncoder encoder = new UrlEncoder(this.url);
            size_t i = 0;
            this.url_encoding_buffer.length = 0;
            foreach (chunk; encoder)
            {
                this.url_encoding_buffer ~= chunk;
            }
            //PercentEncoding.encode(this.url, this.url, this.url_encoding_buffer);
            this.url = this.url_encoding_buffer;
            return this.url;
        }


        /***********************************************************************

            IConnection interface method. Sets connection authorization.

            Params:
                user = username
                passwd = password

        ***********************************************************************/

        public void authorize ( char[] user, char[] passwd )
        {
            this.auth_string.concat(user, ":", passwd, "\0");

            curl_easy_setopt(this.easy, CURLoption.USERPWD, this.auth_string.ptr);
        }


        /***********************************************************************

            IConnection interface method. Sets verbose mode.

        ***********************************************************************/

        public void verbose ( )
        {
            curl_easy_setopt(this.easy, CURLoption.VERBOSE, 1);
        }


        /***********************************************************************

            IConnection interface method. Sets no accept encoding.

        ***********************************************************************/

        public void acceptNoEncoding ( )
        {
            this.acceptEncoding("identity\0");
        }


        /***********************************************************************

            IConnection interface method. Sets any accept encoding.

        ***********************************************************************/

        public void acceptAnyEncoding ( )
        {
            this.acceptEncoding("\0");
        }


        /***********************************************************************

            IConnection interface method. Sets zlib accept encoding.

        ***********************************************************************/

        public void acceptZlibEncoding ( )
        {
            this.acceptEncoding("deflate\0");
        }


        /***********************************************************************

            IConnection interface method. Sets gzip accept encoding.

        ***********************************************************************/

        public void acceptGzipEncoding ( )
        {
            this.acceptEncoding("gzip\0");
        }


        /***********************************************************************

            IConnection interface method. Sets libcurl to ignore ssl host / peer
            verification errors on this connection.

        ***********************************************************************/

        public void ignoreSSLHost ( )
        {
            curl_easy_setopt(this.easy, CURLoption.SSL_VERIFYHOST, 0);
            curl_easy_setopt(this.easy, CURLoption.SSL_VERIFYPEER, 0);
            curl_easy_setopt(this.easy, CURLoption.NOSIGNAL, 1);
        }


        /***********************************************************************

            IConnection interface method. Allows the following of redirects for
            this connection.

        ***********************************************************************/

        public void allowRedirects ( )
        {
            curl_easy_setopt(this.easy, CURLoption.FOLLOWLOCATION, 1);
        }


        /***********************************************************************

            IConnection interface method. Cancels this connection.

        ***********************************************************************/

        public void cancel ( )
        {
            this.result = CURLcode.CURLE_ABORTED_BY_CALLBACK;
            this.finished();
        }


        /***********************************************************************

            Set accept encoding.

            Params:
                value = encoding type (identity|gzip|deflate)

        ***********************************************************************/

        private void acceptEncoding ( char[] enc_str )
        {
            curl_easy_setopt(this.easy, CURLoption.ENCODING, enc_str.ptr);
        }


        /***********************************************************************

            Called upon download success or error. Checks the http response of
            the connection, calls the finalizer delegate, and sets up a select
            event to trigger popping the next request from the request queue.

        ***********************************************************************/

        private void finalize ( )
        {
            if ( !this.finalized )
            {
                int http_response;
                curl_easy_getinfo(this.easy, CurlInfo.CURLINFO_RESPONSE_CODE, &http_response);

                this.finalizer(this.request_context, this.id_num, this.url[0..$-1], http_response, this.result);

                this.notify();

                this.finalized = true;
            }
        }


        /***********************************************************************

            Sets up a new curl transfer.

        ***********************************************************************/

        private void initTransfer ( )
        {
            curl_easy_setopt(this.easy, CURLoption.URL, this.stripLeadingSpaces(this.url).ptr);
            curl_easy_setopt(this.easy, CURLoption.WRITEFUNCTION, &write_cb);
            curl_easy_setopt(this.easy, CURLoption.WRITEDATA, cast(void*)this);
            curl_easy_setopt(this.easy, CURLoption.TIMEOUT, this.outer.timeout);
            curl_easy_setopt(this.easy, CURLoption.PRIVATE, cast(void*)this);
        }


        // TODO: this actually would be better handled just with an assert in the
        // download() method. This will do for now though.

        /***********************************************************************

            Strips leading spaces from a url and returns a pointer to the first
            non-space character.

            This method is used because libcurl freaks out if a url has a space
            at the start!

            Params:
                url = url to clean

            Returns:
                slice of url with leading spaces removed

        ***********************************************************************/

        private char[] stripLeadingSpaces ( char[] url )
        {
            size_t url_start;
            foreach ( i, c; url )
            {
                if ( c != ' ' )
                {
                    url_start = i;
                    break;
                }
            }

            return url[url_start..$];
        }

        /***********************************************************************

            SelectEvent trigger delegate. Called when the connection ready event
            fires in epoll, indicating that this connection is ready to handle a
            new request, if any are available. If a request can be popped from
            the request queue, then it is processed. Otherwise this connection
            is registered with the request queue as waiting, and will be
            activated when a new request arrives in the queue.

            Returns:
                always false, to unregister from epoll

        ***********************************************************************/

        private bool conn_ready_cb ( )
        {
            auto request = this.outer.queue.pop(this.outer.deserialize_buf);
            if ( request !is null )
            {
                this.download(request);
            }
            else
            {
                this.outer.queue.ready(&this.notify);
            }

            return false;
        }


        /***********************************************************************
        
            Curl callbacks.

        ***********************************************************************/

        static extern ( C )
        {
            /*******************************************************************

                Curl easy write callback. Called when data is received on a
                connection. Passes the received data onto the user-specified
                delegate.

                Params:
                    ptr = pointer to received data
                    size = size in bytes of one data element
                    nmemb = number of data elements
                    conn = curl connection object reference

                Returns:
                    bytes consumed

            *******************************************************************/

            private size_t write_cb ( void* ptr, size_t size, size_t nmemb, CurlConnection conn )
            {
                auto realsize = size * nmemb;
//                Trace.formatln("write_cb: received {} bytes from {}", realsize, conn.url[0..$-1]);

                try // try-catch to prevent exceptions being thrown into libcurl
                {
                    conn.receiver(conn.request_context, conn.id_num, conn.url[0..$-1], (cast(char*)ptr)[0 .. realsize]);
                }
                catch ( Exception e )
                {
                    OceanException.Warn("Exception caught in curl write_cb: '{}'@{}:{}",
                            e.msg, e.file, e.line);
                }

                return realsize;
            }
        }
    }


    /***************************************************************************
    
        Libcurl multi handle -- the global connection manager object.
    
    ***************************************************************************/
    
    private CURLM multi;
    
    
    /***************************************************************************
    
        String used for deserializing queued requests. This buffer is only used
        by the CurlConnection class, which accesses this member as a kind of
        global buffer to be shared by all connections.
    
    ***************************************************************************/
    
    private ubyte[] deserialize_buf;
    
    
    /***************************************************************************
    
        Associative array mapping from a curl easy handle to a curl connection
        object. Used for fast lookup. Created in constructor and never modified.
    
    ***************************************************************************/
    
    private CurlConnection[CURL] connection_lookup;
    
    
    /***************************************************************************
    
        Queue of requests. When a download is requested it is always pushed to
        the queue. The queue then notifies any waiting connections.
    
    ***************************************************************************/
    
    private NotifyingQueue!(CurlRequest) queue;
    
    
    /***************************************************************************
    
        Timer event -- registered as libcurl demands.
    
    ***************************************************************************/
    
    private TimerEvent timer;
    
    
    /***************************************************************************
    
        Flag telling whether the timer event should be unregistered. Used by the
        timer's callback (timer_cb), and passed straight into the select
        dispatcher. The default is to unregister the timer once it has fired,
        but the timer callback calls curl_multi_socket_action, which may in turn
        reuqets that a new timer be set. So we have to allow the case where the
        timer has fired but should *not* be unregistered (it should stay
        registered in the selector with an update time value).
    
    ***************************************************************************/
    
    private bool unregister_timer;
    
    
    /***************************************************************************
    
        Epoll selector -- passed as a reference from outside.
    
     ***************************************************************************/
    
    private EpollSelectDispatcher epoll;
    
    
    /***************************************************************************
    
        Count of the number of active curl connections. Updated by calls to
        curl_multi_socket_action.
    
     ***************************************************************************/
    
    private int still_running;


    /***************************************************************************
    
        List of curl connections, created in the constructor and re-used. The
        length of this array is set once and never changed.
    
    ***************************************************************************/
    
    private CurlConnection[] conns;


    /***************************************************************************

        Global connection timeout value (in seconds).

    ***************************************************************************/

    private uint timeout;


    /***************************************************************************

        Flag set to true when the suspend() method is called, and reset when the
        resume() method is called.

    ***************************************************************************/

    private bool suspended;


    /***************************************************************************
    
        Constructor.
    
        Params:
            epoll = epoll selector to use for libcurl event management
            num_connections = maximum number of parallel curl downloads
    
    ***************************************************************************/
    
    public this ( EpollSelectDispatcher epoll, uint num_connections )
    {
        this.epoll = epoll;
    
        this.queue = new NotifyingQueue!(CurlRequest)(1024 * 1024);
    
        this.timer = new TimerEvent(&this.timer_cb);

        this.timeout = 60; // default timeout = 1 minute

        // Create curl multi stack and set global options.
        this.multi = curl_multi_init();
        curl_multi_setopt(this.multi, CURLMoption.SOCKETFUNCTION, &curl_socket_cb);
        curl_multi_setopt(this.multi, CURLMoption.SOCKETDATA, cast(void*)this);
        curl_multi_setopt(this.multi, CURLMoption.TIMERFUNCTION, &curl_timer_cb);
        curl_multi_setopt(this.multi, CURLMoption.TIMERDATA, cast(void*)this);
    
        // Create connections and register as waiting for requests.
        conns.length = num_connections;
        foreach ( ref conn; this.conns )
        {
            conn = new CurlConnection;
            this.queue.ready(&conn.notify);
            this.connection_lookup[conn.easy] = conn;
        }
        this.connection_lookup.rehash;
    }
    
    
    /***************************************************************************

        Requests the download of a url. The download will be started straight
        away if a connection is free, otherwise it will be queued for execution
        later on.

        Note that if the curl object is currently suspended, due to calling the
        suspend() method, then the new download will be rejected.

        Params:
            url = url to download
            initializer = delegate to be called when the curl easy connection is
                started. Receives an instance of the IConnection interface,
                which provides various connection setup methods.
            receiver = delegate to be called when data is received from the http
                server (may be called multiple times, as chunks of the data are
                received)
            finalizer = delegate to be called when download has finished (may be
                due to success or error)
            context = user specified void* context associated with the request.
                This context is passed to the receiver and finalizer delegates
                when they're called.

        Returns:
            true if the download was started or queued up, false if it was
            ignored due to processing being suspended

    ***************************************************************************/

    public bool download ( char[] url, CurlRequest.Initializer initializer, CurlRequest.Receiver receiver,
            CurlRequest.Finalizer finalizer, void* context = null )
    {
        if ( this.suspended )
        {
            return false;
        }

        CurlRequest request;
        request.url = url;
        request.initializer = initializer;
        request.receiver = receiver;
        request.finalizer = finalizer;
        request.context = context;

        this.queue.push(request);

        return true;
    }


    /***************************************************************************

        Sets the timeout for new connections. (Any processing connections will
        not be modified.)

        Params:
            timeout = timeout in seconds

    ***************************************************************************/

    public void setTimeout ( uint timeout )
    {
        this.timeout = timeout;
    }


    /***************************************************************************

        Returns:
            the number of requests waiting in the queue

    ***************************************************************************/

    public size_t queuedRequests ( )
    {
        return this.queue.length;
    }


    /***************************************************************************

        Suspends the processing of all active connections. No existing downloads
        will be processed until the resume() method is called.

        TODO: if we ever need per-connection suspend/resume, it could work like
        in the queue client -- a delegate is called which provides an interface
        to a connection with suspend() and resume() methods. For now we don't
        need that though.

    ***************************************************************************/

    public void suspend ( )
    {
        if ( !this.suspended )
        {
            foreach ( conn; this.conns )
            {
                if ( conn.fd > 0 )
                {
                    this.epoll.unregister(conn);
                }
            }

            this.suspended = true;
        }
    }


    /***************************************************************************

        Resumes the processing of any connections paused by the suspend()
        method.

        curl_multi_socket_action is called to mimic a timeout, which prompts the
        curl socket callback to reinstate the paused connections. This is
        perhaps not the best way of achieving this, but in the absence of the
        real curl_easy_pause function working properly with the multi socket
        interface, it is a working solution at least.

    ***************************************************************************/

    public void resume ( )
    {
        if ( this.suspended )
        {
            foreach ( conn; this.conns )
            {
                if ( conn.fd > 0 && !conn.finalized )
                {
                    this.epoll.register(conn);
                }
            }

            this.suspended = false;

            // Forces socket_cb to be called to re-register the sockets.
            curl_multi_socket_action(this.multi, CURL_SOCKET_TIMEOUT, 0, &this.still_running);
        }
    }


    /***************************************************************************
    
        Timer callback -- called from the epoll selector when the timer expires.
        Informs libcurl that the timeout it requested has expired.

        Returns:
            false to be unregistered from epoll selector, true to stay
            registered. (The default is to unregister once fired, but the call
            to multi socket action may request another timer to be registered,
            in which case we return true.)

    ***************************************************************************/
    
    private bool timer_cb ( )
    {
        this.unregister_timer = true;

        curl_multi_socket_action(this.multi, CURL_SOCKET_TIMEOUT, 0, &this.still_running);

        return !this.unregister_timer;
    }
    
    
    /***************************************************************************
    
        Unregisters a curl connection from the epoll selector.
    
        Params:
            conn = connection to unregister
    
    ***************************************************************************/
    
    private void unregisterConnection ( CurlConnection conn )
    {
        conn.finished();
    }
    
    
    /***************************************************************************
    
        Registers a curl connection with the epoll selector.
    
        Params:
            socket_fd = socket to register
            easy_handle = curl easy handle to register socket for
            action = socket action to wait on

    ***************************************************************************/
    
    private void registerConnection ( curl_socket_t socket_fd, CURL easy_handle, int action )
    in
    {
        assert((easy_handle in this.connection_lookup) !is null, typeof(this).stringof ~ ".registerConnection: invalid easy handle");
    }
    body
    {
        auto conn = easy_handle in this.connection_lookup;
        if ( conn !is null )
        {
            this.modifyConnectionRegistration(*conn, socket_fd, easy_handle, action);
    
            curl_multi_assign(this.multi, socket_fd, cast(void*)*conn);
        }
    }
    
    
    /***************************************************************************
    
        Modifies the registration of a curl connection in the epoll selector.
    
        Params:
            conn = connection to modify
            socket_fd = socket to modify epoll registration of
            easy_handle = curl easy handle to modify epoll registration of
            action = new socket action to wait on

    ***************************************************************************/

    private void modifyConnectionRegistration ( CurlConnection conn, curl_socket_t socket_fd, CURL easy_handle, int action )
    in
    {
        assert(conn.easy == easy_handle, typeof(this).stringof ~ ".modifyConnectionRegistration: easy handle mismatch");
    }
    body
    {
        conn.fd = socket_fd;
        conn.action = action;

        if ( !this.suspended )
        {
            // Tried twice to handle the case where epoll_ctl(ADD) fails and we need
            // to redo it as epoll_ctl(MOD).
            try
            {
                this.epoll.register(conn);
            }
            catch ( Exception e )
            {
                this.epoll.register(conn);
            }
        }
    }


    /***************************************************************************

        Sets the message code for a connection.

        Params:
            easy_handle = curl easy handle to set message for
            result = message code

    ***************************************************************************/

    private void setConnectionMessage ( CURL easy_handle, CURLcode result )
    {
        auto conn = easy_handle in this.connection_lookup;
        if ( conn !is null )
        {
            conn.result = result;
        }
    }


    /***************************************************************************
    
        Curl callbacks.
    
    ***************************************************************************/
    
    static extern ( C )
    {
        /***********************************************************************
    
            Timer callback. Called by curl to indicate that it requires a timer
            event to be registered.
    
            Params:
                multi = curl multi handle
                timeout_ms = timeout (in ms) to set
                g = global curl manager reference
    
            Returns:
                always 0 (obligatory)
    
        ***********************************************************************/
    
        private int curl_timer_cb ( CURLM multi, int timeout_ms, LibCurlEpoll g )
        {
            try // try-catch to prevent exceptions being thrown into libcurl
            {
                if ( timeout_ms >= 0 )
                {
                    // curl sometimes requests timeout values of 0ms, which are
                    // meaningless to our TimerEvent, so we always set at least a
                    // 1ms timer.
                    if ( timeout_ms == 0 )
                    {
                        timeout_ms = 1;
                    }
                    
                    g.timer.set(timeout_ms / 1000, timeout_ms % 1000);
                    g.epoll.register(g.timer);
                    g.unregister_timer = false;
                }
            }
            catch ( Exception e )
            {
                OceanException.Warn("Exception caught in curl timer_cb: {}", e.msg);
            }
    
            return 0; // obligatory
        }
    
    
        /***********************************************************************

            Socket callback. Called by curl to indicate that a socket it is
            using to send/receive data requires attention.

            Params:
                easy_handle = easy handle for connection which needs
                    modification
                socket_fd = file descriptor of socket
                action = action which occurred
                g = global curl manager reference
                conn = connection reference

            Returns:
                always 0 (obligatory)

        ***********************************************************************/
    
        private int curl_socket_cb ( CURL easy_handle, curl_socket_t socket_fd, int action, LibCurlEpoll g, CurlConnection conn )
        {
            debug const char[][] actionstr = ["none", "IN", "OUT", "INOUT", "REMOVE"];

//            Trace.formatln("[{}]: {}", socket_fd, actionstr[action]);

            try // try-catch to prevent exceptions being thrown into libcurl
            {
                // Check any pending messages (connection result codes)
                CURLMsg* msg;
                int msgs_in_queue;
                do
                {
                    msg = curl_multi_info_read(g.multi, &msgs_in_queue);
                    if ( msg !is null && msg.msg == CURLMSG.CURLMSG_DONE )
                    {
                        g.setConnectionMessage(msg.easy_handle, msg.data.result);
                    }
                }
                while ( msg !is null );

                // Handle this action
                if ( action == CURL_POLL_REMOVE )
                {
                    g.unregisterConnection(conn);
                }
                else
                {
                    if ( conn is null )
                    {
                        g.registerConnection(socket_fd, easy_handle, action);
                    }
                    else
                    {
                        assert(easy_handle == conn.easy);
                        assert(socket_fd == conn.fd);
                        
                        g.modifyConnectionRegistration(conn, socket_fd, easy_handle, action);
                    }
                }
            }
            catch ( Exception e )
            {
                OceanException.Warn("Exception caught in curl socket_cb: {}", e.msg);
            }

            return 0; // obligatory
        }
    }
}


// TODO: check curl return codes

/* Die if we get a bad CURLMcode somewhere */ 
/*static void mcode_or_die(const char *where, CURLMcode code)
{
if ( CURLM_OK != code ) {
const char *s;
switch (code) {
  case     CURLM_CALL_MULTI_PERFORM: s="CURLM_CALL_MULTI_PERFORM"; break;
  case     CURLM_BAD_HANDLE:         s="CURLM_BAD_HANDLE";         break;
  case     CURLM_BAD_EASY_HANDLE:    s="CURLM_BAD_EASY_HANDLE";    break;
  case     CURLM_OUT_OF_MEMORY:      s="CURLM_OUT_OF_MEMORY";      break;
  case     CURLM_INTERNAL_ERROR:     s="CURLM_INTERNAL_ERROR";     break;
  case     CURLM_UNKNOWN_OPTION:     s="CURLM_UNKNOWN_OPTION";     break;
  case     CURLM_LAST:               s="CURLM_LAST";               break;
  default: s="CURLM_unknown";
    break;
case     CURLM_BAD_SOCKET:         s="CURLM_BAD_SOCKET";
  fprintf(MSG_OUT, "ERROR: %s returns %s\n", where, s);
   ignore this error  
  return;
}
fprintf(MSG_OUT, "ERROR: %s returns %s\n", where, s);
exit(code);
}
}
*/ 
