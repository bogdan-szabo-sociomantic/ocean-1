/*******************************************************************************

    Http Server (Async epoll-based)

    Copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    Version:        Feb 2009: Initial release

    Authors:        Lars Kirchhoff, Thomas Nicolai & David Eckhardt

*******************************************************************************/

module      ocean.net.http.HttpServer;


/*******************************************************************************

    Imports

*******************************************************************************/


public      import      ocean.net.http2.HttpException: HttpServerException;

public      import      ocean.core.Exception: assertEx;

public      import      ocean.util.OceanException;

private     import      tango.core.Exception: SocketException;

private     import      tango.core.ThreadPool;

private     import      tango.io.selector.EpollSelector;

private     import      tango.net.device.Socket, tango.net.InternetAddress;

private     import      tango.sys.linux.linux;

debug
{
    private     import      tango.util.log.Trace;
}

/*******************************************************************************

    Constants

********************************************************************************/

private     const int           EPOLLWAIT_INFINITE = -1;


/*******************************************************************************

    Http server creates a socket server listening for incoming requests and
    passes the child socket to a thread function.

    Usage example for server with 10 threads
    ---
    scope server = new HttpServer(10);
    ---

    Set thread handler delegate to handle request and start server
    ---
    int reply ( Socket socket )
    {
        ...
    }

    server.setThreadFunction(&reply);
    server.start();
    ---
    ---


    Usage example on creating server with using an object pool
    ---
    scope pool   = new ObjectPool!(HttpRequest);
    scope server = new HttpServer(10);
    ---

    Setting up the delegate function to be called on a request
    ---
    int reply ( Socket socket )
    {
        char[] data;
        HttpResponse response;

        auto request  = pool.get();         // get request object

        scope (exit)
        {
            pool.recycle(request);       // put back on stack on exit
        }

        bool status = request.read(socket, data);

        return 0;
    }
    ---

    Setting the delegate function and starting the server
    ---
    server.setThreadFunction(&reply);
    server.start();
    ---
    ---


*******************************************************************************/

class HttpServer
{

    /*******************************************************************************

         Number of server threads

    ********************************************************************************/

    private             uint                                    number_threads;

    /*******************************************************************************

        Child process

     *******************************************************************************/

    private             pid_t                                   child_id;

    /*******************************************************************************

        Socket connection delegate

     *******************************************************************************/

    private             alias int delegate(Socket conduit)      ThreadDl;

    /*******************************************************************************

         Socket & EPoll

     *******************************************************************************/

    private             ServerSocket                            socket;
    private             EpollSelector                           epoll;

    /*******************************************************************************

        Socket connection thread pool

     *******************************************************************************/

    private             alias ThreadPool!(Socket, ThreadDl)     SocketThreadPool;
    private             SocketThreadPool                        thread_pool;

    /*******************************************************************************

         Delegate to handle socket connections

     *******************************************************************************/

    private             ThreadDl                                thread_func;

    /*******************************************************************************

        Constructor; creates http server socket

        Performance tuning!!!
        ---
        The backlog determines the maximum number of connections queued. By default
        this parameter is limited to 128 on Linux. However, you can raise this limit.
        Moreover, the tcp timeout, the keepalive and open file descriptor limit can
        be raised too.

        [Backlog]

        echo 3000 > /proc/sys/net/core/netdev_max_backlog
        echo 3000 > /proc/sys/net/core/somaxconn

        [Timeout]

        echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout

        [Keepalive]

        echo 15 > /proc/sys/net/ipv4/tcp_keepalive_intvl

        [Open file limit]

        ulimit -n 8192

        [TIME-WAIT]

        echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse

        [TCP-KEEPALIVE-PROBES]

        echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes

        [TCP-KEEPALIVE-INTERVAL]

        echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl

        [TCP-FIN-TIMEOUT]

        echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout

        For more information

        http://redmine.lighttpd.net/wiki/1/Docs:Performance
        http://www.speedguide.net/read_articles.php?id=121
        ---


        Params:
            threads = number of worker threads
            socket_port = server port
            backlog = size of backlog
            reuse = enable/disable socket reuse

     *******************************************************************************/

    this ( uint threads = 1, uint port = 80, uint backlog = 1024, bool reuse = true )
    {
        this.number_threads = threads;
        this.child_id       = getpid();

        this.bind(new InternetAddress(port), backlog, reuse);
    }


    /*******************************************************************************

        Set the thread delegate function

        When possible this function should be executed within its own thread as
        long as the request and response class are not updated to be working 100%
        async. Until this you should also use a thread object pool to manage the
        different threads and objects efficiently.

        Usage example
        ---
        import ocean.core.ObjectPool;
        import ocean.net.http.HttpRequest;

        scope pool = new ObjectPool!(HttpRequest);
        ---

        Get thread instance with request object from pool and Put it back on the
        stack once done to be reused on next request
        ---
        int reply ( Socket socket )
        {
            auto request = pool.get();

            scope (exit)
            {
                request.recycle(request);
            }

            ...
        }

        server.setThreadFunction(&reply);
        ---
        ---

        Params:
            thread_func_dg = thread function delegate

        Returns:
            void

     *******************************************************************************/

    public void setThreadFunction ( ThreadDl thread_func_dg )
    {
        this.thread_func = thread_func_dg;
    }


    /*******************************************************************************

        Start and listen to the server socket asynchronously.

        TODO: solve problem with multi-thread socket problem
        http://kerneltrap.org/mailarchive/linux-kernel/2010/3/3/4544339/thread

        Method binds to the non-blocking server socket and creates an epoll event
        listener for incoming socket requests. If an event is triggered the child
        socket is passed on to the delegete thread function set via the
        setThreadFunction() method.

        Returns:
            void

     *******************************************************************************/

    public int start ()
    {
        int event_count;

        createThreadpool();

        this.epoll = new EpollSelector();

        this.epoll.open(100, 64);
        //this.epoll.register(this.socket, Event.Read  | Event.Hangup |
        //                                 Event.Error | Event.InvalidHandle);
        this.epoll.register(this.socket, Event.Read);

        scope(exit)
        {
            this.epoll.close;
            this.socket.shutdown;
            this.socket.close;
        }

        this.socket.socket.blocking(false);     //  set non-blocking

        while (true)
        {
            try
            {
                event_count = this.epoll.select(EPOLLWAIT_INFINITE);
            }
            catch (Exception e)
            {
                debug
                {
                    Trace.formatln("select error {}", e.msg);
                }
            }

            if (event_count > 0)
            {
                try
                {
                    foreach (SelectionKey key; this.epoll.selectedSet())
                    {
                        if ( key.isReadable && key.conduit is socket )
                        {
                            try
                            {
                                this.runThread((cast(ServerSocket) key.conduit).accept());
                            }
                            catch (Exception e)
                            {
                                assertEx!(SocketException)(false, `socket accept error`);
                            }
                        }
                        else if (key.isError() || key.isHangup() || key.isInvalidHandle())
                        {
                            debug
                            {
                                Trace.formatln(`key error`);
                            }
                        }
                        else
                        {
                            debug
                            {
                                Trace.formatln(`unknown socket error`);
                            }
                        }
                    }
                }
                catch ( Exception e )
                {
                    OceanException.Warn(`socket accept error`, e.msg);
                }
            }
            else
            {
                debug
                {
                    Trace.formatln("Event count <= 0");
                }
            }

            this.epoll.register(this.socket, Event.Read  | Event.Hangup |
                                             Event.Error | Event.InvalidHandle);
        }

        return 0;
    }


    /*******************************************************************************

        Creates new server socket.

        Params:
            address = internet address to bind socket to
            backlog = max number of socket connections to keep in the backlog
            reuse   = enable/disable socket reuse

        Returns:
            void

     *******************************************************************************/

    private void bind ( InternetAddress address, uint backlog, bool reuse )
    {
        this.socket = new ServerSocket(address, backlog, reuse);
    }


    /*******************************************************************************

        Creates thread pool.

        Returns:
            void

     *******************************************************************************/

    private void createThreadpool ()
    {
        this.thread_pool = new SocketThreadPool(this.number_threads);
    }


    /*******************************************************************************

        Runs the request handler thread function

        Function that assigns the thread action to the ThreadPool together with the
        socket.

        TODO

        Add a timeout after which a thread is freed again; set running = false

        Params:
            socket = socket connection

        Returns:
            void

     *******************************************************************************/

    private void runThread ( Socket socket )
    {
        this.thread_pool.assign(&this.threadAction, socket, this.thread_func);
    }


    /*******************************************************************************

        Executes the thread delegate function passed to setThreadFunction()

        Method calls delegate and detaches the socket if the thread finished
        serving the request.

        Params:
            socket   = socket connection
            selector = epoll selector

        Returns:
            void

     *******************************************************************************/

    private void threadAction ( Socket socket, ThreadDl dg )
    {
        try
        {
            if ( socket !is null )
            {
                scope (exit)
                {
                    socket.shutdown();
                    socket.detach();
                }

                dg(socket);
            }
        }
        catch (Exception e)
        {
            OceanException.Warn(`HttpServer Error: {}`, e.msg);
        }
    }

}
