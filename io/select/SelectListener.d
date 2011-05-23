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

    SelectListener base class
    
    Contains all base functionality which is not related to the particular
    IConnectionHandler subclass used in SelectListener.

 ******************************************************************************/

abstract class ISelectListener : ISelectClient
{
    /**************************************************************************

        SelectDispatcher instance
    
     **************************************************************************/
    
    private EpollSelectDispatcher dispatcher;
    
    /**************************************************************************

        Termination flag; true prevents accepting new connections
    
     **************************************************************************/

    private bool terminated = false;
    
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
    
    protected this ( IPv4Address address, EpollSelectDispatcher dispatcher,
                     int backlog = 32, bool reuse = true )
    {
        auto socket = new ServerSocket(address, backlog, reuse);
        socket.socket.noDelay(true).blocking(false);
        
        super(socket);
        
        this.dispatcher = dispatcher;
        
        dispatcher.register(this);
    }

    /**************************************************************************

        Runs the server event loop.
        
        Returns:
            this instance
        
     **************************************************************************/
    
    final typeof (this) eventLoop ( )
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
    
    final Event events ( )
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
    
    final bool handle ( Event event )
    {
        if (!this.terminated)
        {
            this.getConnectionHandler().assign((ISelectable connection_conduit)
            {
                Socket connection_socket = cast (Socket) connection_conduit;
                (cast (ServerSocket) super.conduit).accept(connection_socket);
                connection_socket.socket.noDelay(true).blocking(false);
            });
        }
        
        return !this.terminated;
    }
    
    /**************************************************************************
    
        Closes the server socket and sets this instance to terminated mode.
        
        TODO: Make it possible to reopen the server socket and resume operation? 
        
        Returns:
            true if this instance was already in to terminated mode or false
            otherwise
    
     **************************************************************************/

    final bool terminate ( )
    {
        scope (exit) if (!this.terminated)
        {
            this.terminated = true;
            
            (cast (Socket) super.conduit).shutdown().close();
        }
        
        return this.terminated;
    }
    
    /**************************************************************************
    
        Returns:
            information interface to the connections pool
    
     **************************************************************************/
    
    abstract IObjectPoolInfo poolInfo ( );
    
    /**************************************************************************
        
        Obtains a connection handler instance from the pool.
        
        Returns:
            connection handler
    
     **************************************************************************/
    
    abstract protected IConnectionHandler getConnectionHandler ( );
    
    /**************************************************************************
    
        Class ID string for debugging
    
     **************************************************************************/
    
    debug (ISelectClient) abstract char[] id ( );
}

/******************************************************************************

    SelectListener class template
    
    The additional T constructor argument parameters must appear after those for
    the mandatory IConnectionHandler constructor.
    
    Template params:
        T    = connection handler class
        Args = additional constructor arguments for T

 ******************************************************************************/

class SelectListener ( T : IConnectionHandler, Args ... ) : ISelectListener
{
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
        super(address, dispatcher, backlog, reuse);
        
        this.receiver_pool = this.receiver_pool.newPool(dispatcher,
                                                        &this.returnToPool,
                                                        args);
    }
    
    /**************************************************************************
    
        Obtains a connection handler instance from the pool.
        
        Returns:
            connection handler
    
     **************************************************************************/

    protected IConnectionHandler getConnectionHandler ( )
    {
        return this.receiver_pool.get();
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
        T item = cast (T) connection;
        
        assert (item);
        
        this.receiver_pool.recycle(item);
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
