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


public      import      ocean.core.Exception: HttpServerException;

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
       
    private             uint                            number_threads;
    
    /*******************************************************************************
    
        Child process
    
     *******************************************************************************/
    
    private             pid_t                           child_id;
        
    /*******************************************************************************

         Socket & EPoll

     *******************************************************************************/
    
    private             ServerSocket                    socket;     
    private             EpollSelector                   selector;
    
    /*******************************************************************************
    
        Socket Connection Handler Thread
            
        thread_pool = thread pool managing socket connections
        thread_func     delegate called to handle socket connections
    
     *******************************************************************************/
    
    private             ThreadPool!(Socket)             thread_pool;
    private             int delegate(Socket)            thread_func;
    
    
    /*******************************************************************************
        
        Constructor; creates http server socket
        
        Params:
            number_threads = number of worker threads
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

    public void setThreadFunction ( int delegate(Socket conduit) thread_func_dg )
    {
        this.thread_func = thread_func_dg;
    }


    /*******************************************************************************
        
        Start and listen to the server socket asynchronously.
        
        Method binds to the non-blocking server socket and creates an epoll event 
        listener for incoming socket requests. If an event is triggered the child
        socket is passed on to the delegete thread function set via the 
        setThreadFunction() method.

        Returns:
            void
                
     *******************************************************************************/
    
    public int start () 
    {   
        int                 event_count;         
        Socket              conduit;
        int                 conduit_filehandle;
        Socket[int]         connections;        // socket connection pool
        
        createThreadpool();
        
        this.selector = new EpollSelector(); 
        
        this.selector.open(500, 64);
        this.selector.register(this.socket, Event.Read | Event.Hangup | 
                                            Event.Error | Event.InvalidHandle);     
        
        scope(exit) 
        {
            this.selector.close;
            this.socket.shutdown;
            this.socket.close;
        }
        
        this.socket.socket.blocking(false);     //  set non-blocking
       
        while(true)
        {  
            try 
            {
                event_count = this.selector.select(EPOLLWAIT_INFINITE);
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
                foreach (SelectionKey key; this.selector.selectedSet())
                {
                    // Check if key event conduit is a ServerSocket. If yes
                    // accept socket connection and put socket conduit in 
                    // socket conduit array for later usage.
                    // Assign the new socket conduit to EPollSelector.
                    if (key.conduit is socket) 
                    {
                        conduit = (cast(ServerSocket) key.conduit).accept();
                        
                        conduit_filehandle              = conduit.fileHandle();
                        connections[conduit_filehandle] = conduit; 

                        // Run thread non blocking reading/writing is done in the 
                        // HttpRequest/HttpResponse object
                        //
                        // TODO this is nuts! passing on the stuff to the thread
                        //      makes the server stall. in case the server runs
                        //      with 10 threads and 10 clients sending data
                        //      the server can only handle 10 parallel request.
                        //      the stuff should only be passed to a thread
                        //      once the incoming data was read.
                        this.runThread(connections[conduit_filehandle]);                        
                    }
                    else if (key.isError() || key.isHangup() || key.isInvalidHandle())
                    {
                        debug
                        {
                            Trace.formatln("socket error; unregister from selector");
                        }
                        
                        this.selector.unregister(key.conduit);                              
                    }
                    else
                    {
                        debug
                        {
                            Trace.formatln("unknown socket error");
                        }
                    }
                }
            }
            else 
            {
                debug
                {
                    Trace.formatln("Event count <= 0");
                }
            }
            
            selector.register(this.socket, Event.Read  | Event.Hangup | 
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
        this.thread_pool = new ThreadPool!(Socket)(this.number_threads);                
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
        thread_pool.assign(&this.threadAction, socket);
    }
    
    
    /*******************************************************************************
        
        Executes the thread delegate function passed to setThreadFunction()
        
        Method calls delegate and detaches the socket if the thread finished 
        serving the request.
            
        Params:
            socket = socket connection
            
        Returns:
            void
                
     *******************************************************************************/

    private void threadAction ( Socket socket )
    {
        assert(this.thread_func, "No thread delegate given!");
        
        this.thread_func(socket); // run func inside thread
       
        try 
        {
            if (socket)
            {
                socket.shutdown();
                socket.detach();
                
                this.selector.unregister(socket);
            }
        }
        catch (Exception e)
        {
            throw new HttpServerException("HttpServer Error: " ~ e.msg);            
        }
    }
    
}
