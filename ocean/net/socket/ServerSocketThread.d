/*******************************************************************************

    Server Socket thread
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        March 2010: Initial release
    
    authors:        David Eckardt
    
    Description:
    
    Binds to a server socket, waits for connections to arrive and invokes a
    connection handler in a separate thread on incoming connection.
    
    Usage:
    
    ServerSocketThread class template parameters are:
    
        ConnectionHandler : IConnectionHandler = connection handler class
        
        Args = ConnectionHandler constructor argument types; leave empty for no
               argument
    
    ---
    
        import $(TITLE);
        import ocean.net.socket.model.IConnectionHandler;
    
        import tango.net.InternetAddress;
        import tango.net.device.Socket;
        
        // Define connection handler class. It must be derived from
        // IConnectionHandler and implement the dispatch() method. For socket
        // I/O the inherited class properties ListReader reader and 
        // ListWriter writer are available.
        
        class MyConnHandler : IConnectionHandler
        {
            this ( int eggs, char[] spam )
            {
                // ...
            }
        
            protected void dispatch ( )
            {
                // write something to the socket
            
                super.writer.put("Hello world!");
            }
        }
        
        // Run server on example.net:4711
        
        int    eggs = 42;
        char[] spam = "abcde";
        
        const ServerThreads = 10;
        
        auto address = new InternetAddress("example.net", 4711);      
        
        auto socket  = new ServerSocket(address, this.backlog, this.reuse);
        
        // The 'int' ServerSocketThread template parameter reflects
        // MyConnHandler's constructor argument types
        
        auto thread = new ServerSocketThread!(MyConnHandler, int, char[])(socket, eggs, spam, ServerThreads)
        
        thread.start();
    
    ---
    
 ******************************************************************************/

module net.socket.SocketThread;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private  import  ocean.net.socket.model.IConnectionHandler;

private  import  ocean.core.ObjectThreadPool;

private  import  ocean.util.TraceLog;

private  import  tango.net.device.Socket;
private  import  tango.net.device.Berkeley: Address;
private  import  tango.net.InternetAddress;

private  import  tango.core.Thread: Thread;

private  import  Thread_ = tango.core.Thread: thread_joinAll;

private  import  tango.core.Runtime;

debug
{
	private import tango.util.log.Trace;
}

/*******************************************************************************

    SocketThread
    
 ******************************************************************************/

class ServerSocketThread ( ConnectionHandler : IConnectionHandler, Args ... ) : Thread
{
    /***************************************************************************
    
        Call joinAll() like a static method do wait for all threads to finish.
        
     **************************************************************************/

    public alias        Thread_.thread_joinAll          joinAll;
    
    /***************************************************************************
    
        Default timeout of -1 for infinite connection timeout        
        Please do not modify this value. Timeouts should always be handled 
        in the client not by the server. 
        
     **************************************************************************/

    public const        uint                            Timeout        = -1;
    
    /***************************************************************************
    
        Maximum number of accepted pending connections
        
     **************************************************************************/
    
    public              uint                            conn_queue_max = 100;
    
    /***************************************************************************
        
        Server socket
        
     **************************************************************************/
    
    protected           ServerSocket                    server_socket;
    
    /***************************************************************************
    
        Termination flag for listener loop
        
     **************************************************************************/

    private           bool                            terminated = false;
    
    /***************************************************************************
    
        Connection pool
        
     **************************************************************************/

    private             ObjectThreadPool!(ConnectionHandler, Args) connections;
    
    /***************************************************************************
        
        Constructor
        
        socket       = server socket
        args         = ConnectionHandler constructor arguments (no argument if
                       Args left empty)
        conn_threads = number of connection threads
        
     **************************************************************************/
    
    this ( ServerSocket server_socket, Args args, uint n_conn_threads )
    {
        this.server_socket = server_socket;
        this.connections   = this.connections.newPool(args, n_conn_threads, this.conn_queue_max);
        
        this.server_socket.timeout(this.Timeout);
        
        super(&this.listen);
    }
    
    /***************************************************************************
    
        Constructor
        
        address      = Address instange holding server address data
        args         = ConnectionHandler constructor arguments (no argument if
                       Args left empty)
        backlog      = server socket backlog size
        reuse        = socket reuse flag
        conn_threads = number of connection threads
        
     **************************************************************************/

    this ( Address address, Args args, int backlog, bool reuse, uint n_conn_threads )
    {
        this(new ServerSocket(address, backlog, reuse), args, n_conn_threads);
    }
    
    /***************************************************************************
    
        Constructor
        
        address      = server address
        port         = server Port
        args         = ConnectionHandler constructor arguments (no argument if
                       Args left empty)
        backlog      = server socket backlog size
        reuse        = socket reuse flag
        conn_threads = number of connection threads
        
     **************************************************************************/

    this ( char[] address, ushort port, Args args, int backlog, bool reuse, uint n_conn_threads )
    {
        this(new ServerSocket(new InternetAddress(address, port), backlog, reuse), args, n_conn_threads);
    }
    
    /***************************************************************************
    
        Shuts down the server
        
     **************************************************************************/

    public void shutdown ( )
    {
        this.terminated = true;
        
        IConnectionHandler.terminate();
        
        this.server_socket.shutdown();
        this.server_socket.detach();
    }

    /***************************************************************************
        
        Listens to socket; starts a connection handler on incoming connection
        
     **************************************************************************/
    
    private void listen ( )
    {
        uint conn_count = 0;
        
        while (!(Runtime.isHalting() || this.terminated))
        {
            try 
            {
                Socket socket = this.server_socket.accept();
                
                if (this.terminated) return;
                
                if (socket)
                {
                    socket.checkError();
                    
                    if (this.connections.pendingJobs < this.conn_queue_max)
                    {
                    	debug Trace.formatln("Accepting new connection").flush();                    	
                        this.connections.append(socket);
                    }
                    else
                    {
                    	debug Trace.formatln("Max connection queue number reached... ").flush();
                        socket.shutdown();
                        socket.detach();
                    }
                }
                else if (socket.isAlive)
                {
                    TraceLog.write("Socket.accept failed");
                }
           }
           catch (Exception e)
           {
               TraceLog.write("Exception: " ~ e.msg);
           }
        }
    }    
}