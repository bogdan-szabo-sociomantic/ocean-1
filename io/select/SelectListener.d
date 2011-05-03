/******************************************************************************

    Server socket listener using multiplexed non-blocking socket I/O 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt

    Creates a server socket and a pool of connection handlers and registers
    the server socket for incoming connection in a provided SelectDispatcher
    instance. When a connection comes in, takes an IConnectionHandler instance
    from the pool and assigns the incoming connection to the handler's socket.

    Usage example:
    
    ---
        
        import tango.io.select.EpollSelector;
        import ocean.io.select.SelectDispatcher;
        
        import ocean.io.select.SelectListener;
        import ocean.io.select.model.IConnectionHandler;
        
        class MyConnectionHandler : IConnectionHandler
        {
            this ( SelectDispatcher dispatcher, FinalizeDg finalize_dg,         // for IConnectionHandler constructor
                   int x, char[] str )                                          // additional for this constructor
            {
                super(dispatcher, finalize_dg);                                 // mandatory IConnectionHandler
                                                                                // constructor call
                // ...
            }
        }
        
        void main ( )
        {
            char[] address = "localhost";
            ushort port    = 4711;
        
            int x = 4;
            char[] str = "Hello World!";
            
            scope dispatcher = new SelectDispatcher(new EpollSelector,
                                                    EpollSelector.DefaultSize,  
                                                    EpollSelector.DefaultMaxEvents);
            
            scope listener = new SelectListener!(MyConnectionHandler,
                                                 int, char[])                   // types of additional MyConnectionHandler
                                                (address, port, dispatcher,     // constructor arguments x and str
                                                 x, str);
        }
    
    ---
    


 ******************************************************************************/

module ocean.io.select.SelectListener;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.EpollSelectDispatcher,
               ocean.io.select.model.ISelectClient,
               ocean.io.select.model.IConnectionHandler;

import ocean.core.ObjectPool;

import tango.net.device.Socket,
       tango.net.device.Berkeley: IPv4Address;

debug private import tango.util.log.Trace;



/******************************************************************************

    SelectListener class template
    
    The additional T constructor argument parameters must appear after those for
    the mandatory IConnectionHandler constructor.
    
    Template params:
        T    = connection handler class
        Args = additional constructor arguments for T

 ******************************************************************************/

class SelectListener ( T : IConnectionHandler, Args ... ) : ISelectClient
{
    /**************************************************************************

        SelectDispatcher instance
    
     **************************************************************************/

    private EpollSelectDispatcher dispatcher;
    
    /**************************************************************************

        ObjectPool of connection handlers
    
     **************************************************************************/

    private ObjectPool!(T, EpollSelectDispatcher, IConnectionHandler.FinalizeDg,
                        Args) receiver_pool;

    /**************************************************************************

        Constructor
        
        Creates the server socket and registers it for incoming connections.
        
        Params:
            address    = server address
            port       = listening port
            dispatcher = SelectDispatcher instance to use
            args       = additional T constructor arguments, might be empty
            backlog    = (see ServerSocket constructor in tango.net.device.Socket)
            reuse      = (see ServerSocket constructor in tango.net.device.Socket)
        
     **************************************************************************/

    this ( char[] address, ushort port, EpollSelectDispatcher dispatcher,
           Args args, int backlog = 32, bool reuse = true )
    {
        this(new IPv4Address(address, port), dispatcher, args, backlog, reuse);
    }
    
    /**************************************************************************

        Constructor
        
        Creates the server socket and registers it for incoming connections.
        
        Params:
            port       = listening port
            dispatcher = SelectDispatcher instance to use
            args       = additional T constructor arguments, might be empty
            backlog    = (see ServerSocket constructor in tango.net.device.Socket)
            reuse      = (see ServerSocket constructor in tango.net.device.Socket)
        
     **************************************************************************/

    this ( ushort port, EpollSelectDispatcher dispatcher,
           Args args, int backlog = 32, bool reuse = true )
    {
        this(new IPv4Address(port), dispatcher, args, backlog, reuse);
    }

    /**************************************************************************

        Constructor
        
        Creates the server socket and registers it for incoming connections.
        
        Params:
            address    = server address
            dispatcher = SelectDispatcher instance to use
            args       = additional T constructor arguments, might be empty
            backlog    = (see ServerSocket constructor in tango.net.device.Socket)
            reuse      = (see ServerSocket constructor in tango.net.device.Socket)
        
     **************************************************************************/

    this ( IPv4Address address, EpollSelectDispatcher dispatcher,
           Args args, int backlog = 32, bool reuse = true )
    {
        this.dispatcher = dispatcher;
        
        auto socket = new ServerSocket(address, backlog, reuse);
        socket.socket.noDelay(true).blocking(false);
        
        super(socket);
        
        this.receiver_pool = this.receiver_pool.newPool(dispatcher,
                                                        &this.returnToPool,
                                                        args);
        
        dispatcher.register(this);
    }
    
    /**************************************************************************

        Runs the server event loop.
        
        Returns:
            this instance
        
     **************************************************************************/

    public typeof (this) eventLoop ( )
    {
        this.dispatcher.eventLoop();
        
        return this;
    }
    
    /**************************************************************************

        Returns the I/O events to register the device for.
        
        Called from SelectDispatcher during event loop.
        
        Returns:
             the I/O events to register the device for (Event.Read)
    
     **************************************************************************/

    public Event events ( )
    {
        return Event.Read;
    }
    
    /**************************************************************************

        I/O event handler

        Called from SelectDispatcher during event loop.

        Params:
             event = identifier of I/O event that just occured on the device

        Returns:
            true if the handler should be called again on next event occurrence
            or false if this instance should be unregistered from the
            SelectDispatcher (this is effectively a server shutdown).

     **************************************************************************/

    public bool handle ( Event event )
    {
        auto new_connection = this.receiver_pool.get();

        new_connection.assign(
            (ISelectable connection_conduit)
            {
                Socket connection_socket = cast (Socket) connection_conduit;
    
                (cast (ServerSocket) super.conduit).accept(connection_socket);
                connection_socket.socket.noDelay(true).blocking(false);
            });

        return true;
    }

    /**************************************************************************

        Returns:
            information interface to the connections pool

     **************************************************************************/

    public IObjectPoolInfo poolInfo ( )
    {
        return this.receiver_pool;
    }

    /**************************************************************************

        Called as the finalizer of class T. Returns connection into the object
        pool.

        Params:
            connection = connection hander instance to return into pool

     **************************************************************************/

    private void returnToPool ( IConnectionHandler connection )
    {
        this.receiver_pool.recycle(cast (T) connection);
    }
    
    /**************************************************************************

        Class ID string for debugging
    
     **************************************************************************/

    debug (ISelectClient)
    {
        const ClassId = typeof (this).stringof;
        
        public char[] id ( )
        {
            return this.ClassId;
        }
    }
}

