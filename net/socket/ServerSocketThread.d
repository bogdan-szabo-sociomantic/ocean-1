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

private  import  tango.net.device.Socket;

private  import  ocean.net.socket.model.IConnectionHandler;

private  import  tango.core.Thread;
private  import  tango.core.Runtime;

private  import  ocean.core.ObjectThreadPool;

private  import  ocean.util.TraceLog;

/******************************************************************************

    SocketThread
    
 *****************************************************************************/

class ServerSocketThread ( ConnectionHandler : IConnectionHandler, Args ... ) : Thread
{
    /**************************************************************************
        
        Server socket
        
     **************************************************************************/
    
    private             ServerSocket                    socket;
    
    /**************************************************************************
    
        Connection pool
        
     **************************************************************************/

    private             ObjectThreadPool!(ConnectionHandler, Args) connections;
    
    /**************************************************************************
        
        Constructor
        
        socket       = server socket
        args         = ConnectionHandler constructor arguments (no argument if
                       Args left empty)
        conn_threads = number of connection threads
        
     **************************************************************************/
    
    this ( ServerSocket socket, Args args, uint n_conn_threads )
    {
        this.socket      = socket;
        this.connections = this.connections.newPool(args, n_conn_threads);
        
        super(&this.listen);
    }

    /**************************************************************************
        
        Listens to socket; starts a connection handler on incoming connection
        
     **************************************************************************/
    
    private void listen ( )
    {
        while (!Runtime.isHalting())
        {
               try 
               {
                   Socket socket = this.socket.accept();
                   
                   if (socket)
                   {
                       this.connections.assign(socket);
                   }
                   else
                   {
                      if (socket.isAlive)
                      {
                          TraceLog.write("Socket.accept failed");
                      }
                   }
               }
               catch (Exception e)
               {
                   TraceLog.write("IOException: " ~ e.msg);
               }
        }
    }
}
