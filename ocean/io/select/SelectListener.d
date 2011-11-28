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

private import ocean.io.select.model.ISelectClient,
               ocean.io.select.model.IConnectionHandler;

private import ocean.core.ObjectPool;

private import tango.net.device.Socket,
               tango.net.device.Berkeley: IPv4Address;

private import tango.stdc.posix.sys.socket: accept;
private import tango.stdc.posix.unistd:     close;
private import tango.stdc.errno:            errno;

debug private import ocean.util.log.Trace;

/******************************************************************************

    SelectListener base class
    
    Contains all base functionality which is not related to the particular
    IConnectionHandler subclass used in SelectListener.

 ******************************************************************************/

abstract class ISelectListener : ISelectClient
{
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
    
    protected this ( IPv4Address address, int backlog = 32, bool reuse = true )
    {
        auto socket = new ServerSocket(address, backlog, reuse);
        socket.socket.noDelay(true).blocking(false);
        
        super(socket);
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
            with (this.poolInfo) if (!is_limited || num_idle)
            {
                this.acceptConnection();
            }
            else
            {
                this.declineConnection();
            }
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
        
        Sets the limit of the number of connections. 0 disables the limitation.
        
        Notes:
            - If limit is set to something other than 0, limit connection
              handler objects will be created (so set it to a realistic value).
            - If not 0, limit must be at least the number of currently busy
              connections.
        
        Returns:
            information interface to the connections pool
        
     **************************************************************************/

    abstract uint connection_limit ( uint limit ) ;
    
    
    /**************************************************************************
    
        Returns:
            the limit of the number of connections or 0 if limitation is
            disabled.
        
     **************************************************************************/

    public uint connection_limit ( )
    {
        auto n = this.poolInfo.limit;
        
        return (n == n.max)? 0 : n;
    }

    /**************************************************************************
    
        Obtains a connection handler instance from the pool.
        
        Returns:
            connection handler
    
     **************************************************************************/
    
    abstract protected IConnectionHandler getConnectionHandler ( );

    /**************************************************************************
    
        Accepts the next pending incoming client connection and assigns it to
        a connection handler.
        
     **************************************************************************/

    private void acceptConnection ( )
    {
        try
        {
            IConnectionHandler handler = this.getConnectionHandler();
            
            try
            {
                handler.assign((Socket connection_socket)
                {
                    (cast (ServerSocket) super.conduit).accept(connection_socket);
                    connection_socket.socket.noDelay(true).blocking(false);
                });
                
                handler.handleConnection();
            }
            catch (Exception e)
            {
                /* Catch an exception thrown by accept() or handleConnection()
                   (or noDelay()/blocking()) to prevent it from falling through
                   to the select dispatcher which would unregister the server
                   socket.
                   
                   'Too many open files' will be caught here.
                   
                   FIXME: If noDelay() or blocking() fails, the handler will
                   incorrectly assume that the connection is not open and will
                   not close it. Is this a relevant case? */

                handler.error(e);   // will never throw exceptions
                
                handler.finalize();
            }
        }
        catch
        {
            /* Catch an exception (or object) thrown by getConnectionHandler()
               or handler.error() to prevent it from falling through to the
               dispatcher which would unregister the server socket. */
        }
    }
    
    /**************************************************************************
    
        Accepts the next pending incoming client connection and closes it.
        
     **************************************************************************/

    private void declineConnection ( )
    {
        if (.close(.accept(super.conduit.fileHandle, null, null)))              // returns non-zero on failure
        {
            .errno = 0;
        }
    }
}

/******************************************************************************

    SelectListener class template
    
    The additional T constructor argument parameters must appear after those for
    the mandatory IConnectionHandler constructor.
    
    Template params:
        T    = connection handler class
        Args = additional constructor arguments for T

 ******************************************************************************/

public class SelectListener ( T : IConnectionHandler, Args ... ) : ISelectListener
{
    /**************************************************************************

        ObjectPool of connection handlers
    
     **************************************************************************/

    private ObjectPool!(T, IConnectionHandler.FinalizeDg, Args) receiver_pool;

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

    this ( char[] address, ushort port, Args args, int backlog = 32, bool reuse = true )
    {
        this(new IPv4Address(address, port), args, backlog, reuse);
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

    this ( ushort port, Args args, int backlog = 32, bool reuse = true )
    {
        this(new IPv4Address(port), args, backlog, reuse);
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

    this ( IPv4Address address, Args args, int backlog = 32, bool reuse = true )
    {
        super(address, backlog, reuse);
        
        this.receiver_pool = this.receiver_pool.newPool(&this.returnToPool, args);
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
    
        Sets the limit of the number of connections. 0 disables the limitation.
        
        Notes:
            - If limit is set to something other than 0, limit connection
              handler objects will be created (so set it to a realistic value).
            - If not 0, limit must be at least the number of currently busy
              connections.
        
        Returns:
            limit
        
     **************************************************************************/

    public uint connection_limit ( uint limit )
    in
    {
        assert (!(limit && limit < this.poolInfo.num_busy),
                typeof(this).stringof ~ ".connection_limit: limit already exceeded");
    }
    body
    {
        if (limit)
        {
            this.receiver_pool.limit = limit;
        }
        else
        {
            this.receiver_pool.limited = false;
        }
        
        return limit;
    }
    
    /**************************************************************************
        
        (Overriding wrapper to fix method matching.)
        
        Returns:
            new limit of number of connections or 0 if unlimited.
    
     **************************************************************************/

    public override uint connection_limit ( )
    {
        return super.connection_limit;
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

        Closes all connections and terminates the listener.

     **************************************************************************/

    public void shutdown ( )
    {
        foreach ( receiver; this.receiver_pool )
        {
            /* FIXME: calling finalize here will cause errors in any connection
             * handlers which are currently selected in epoll, as they will
             * subsequently attempt to finalize themselves again.
             * 
             * In practice this is of little import however, as the whole server
             * is being shut down. It may be nice to find a clean way to avoid
             * this though.
             */
            receiver.finalize;
        }

        super.terminate;
    }

    /**************************************************************************

        Called as the finalizer of class T. Returns connection into the object
        pool.

        Params:
            connection = connection hander instance to return into pool

     **************************************************************************/

    private void returnToPool ( IConnectionHandler connection )
    in
    {
        assert (cast (T) connection !is null,
                typeof(this).stringof ~ ".returnToPool: connection is null");
    }
    body
    {
        debug ( ConnectionHandler ) Trace.formatln("[{}]: Returning to pool", connection.connection_id);

        this.receiver_pool.recycle(cast (T) connection);
    }
    
    /**************************************************************************

        Class ID string for debugging
    
     **************************************************************************/

    debug public char[] id ( )
    {
        return typeof (this).stringof;
    }
}

