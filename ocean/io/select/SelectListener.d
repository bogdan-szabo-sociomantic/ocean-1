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

    TODO: suggest moving this module to: ocean.io.select.server, along with
    I*ConnectionHandler from ocean.io.select.model.

 ******************************************************************************/

module ocean.io.select.SelectListener;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient,
               ocean.io.select.model.IConnectionHandler;

private import ocean.core.ErrnoIOException;

private import ocean.util.container.pool.ObjectPool : AutoCtorPool;
private import ocean.util.container.pool.model.IPoolInfo;

private import tango.net.device.Socket,
               tango.net.device.Berkeley: IPv4Address;

private import tango.stdc.posix.sys.socket: accept, SOL_SOCKET, SO_ERROR, SO_REUSEADDR;

private import tango.stdc.posix.unistd:     close;
private import tango.stdc.errno:            errno;

private import ocean.sys.socket.AddressIPSocket;

private import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;

debug private import ocean.util.log.Trace;

/******************************************************************************

    SelectListener base class

    Contains all base functionality which is not related to the particular
    IConnectionHandler subclass used in SelectListener.

 ******************************************************************************/

abstract class ISelectListener : ISelectClient
{
    /**************************************************************************

        IP socket, memorises the address most recently passed to bind() or
        connect() or obtained by accept().

     **************************************************************************/

    private const AddressIPSocket!() socket;

    /**************************************************************************

        Termination flag; true prevents accepting new connections

     **************************************************************************/

    private bool terminated = false;

    /**************************************************************************

        Exception instance thrown in case of socket errors.

     **************************************************************************/

    private const SocketError e;

    /**************************************************************************

        Constructor

        Creates the server socket and registers it for incoming connections.

        Params:
            address    = server address
            port       = server port
            backlog    = the maximum length to which the queue of pending
                connections for sockfd may grow. If a connection request arrives
                when the queue is full, the client may receive an error with an
                indication of ECONNREFUSED or, if the underlying protocol
                supports retransmission, the request may be ignored so that a
                later reattempt at connection succeeds.
                (from http://linux.die.net/man/2/listen)

     **************************************************************************/

    protected this ( char[] address, ushort port, int backlog = 32 )
    {
        this();

        this.e.assertExSock(!this.socket.bind(address, port),
                            "error binding socket", __FILE__, __LINE__);

        this.e.assertExSock(!this.socket.listen(backlog),
                            "error listening on socket", __FILE__, __LINE__);
    }

    /**************************************************************************

        Constructor

        Creates the server socket and registers it for incoming connections.

        Params:
            port       = server port
            backlog    = (see ctor above)

     **************************************************************************/

    protected this ( ushort port, int backlog = 32 )
    {
        this();

        this.e.assertExSock(!this.socket.bind(port),
                            "error binding socket", __FILE__, __LINE__);

        this.e.assertExSock(!this.socket.listen(backlog),
                            "error listening on socket", __FILE__, __LINE__);
    }

    /**************************************************************************

        Internal constructor.

     **************************************************************************/

    private this ( )
    {
        this.socket = new AddressIPSocket!();

        this.e = new SocketError(this.socket);

        this.e.assertEx(this.socket.tcpSocket(true) >= 0,
                        "error creating socket", __FILE__, __LINE__);

        this.e.assertEx(!this.socket.setsockoptVal(SOL_SOCKET, SO_REUSEADDR, true),
                        "error enabling reuse of address", __FILE__, __LINE__);

//        this.e.assertEx!(true)(!this.socket.setsockoptVal(SOL_SOCKET, SO_REUSEPORT, true),
//                               "error enabling reuse of port", __FILE__, __LINE__);
    }

    /**************************************************************************

        Implements ISelectClient abstract method.

        Returns:
            events to register the conduit for.

     **************************************************************************/

    public Event events ( )
    {
        return Event.EPOLLIN;
    }

    /**************************************************************************

        Implements ISelectClient abstract method.

        Returns:
            conduit's OS file handle (fd)

     **************************************************************************/

    public Handle fileHandle ( )
    {
        return this.socket.fileHandle;
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

        TODO: accept() could be called in a loop in this method, in order to
        accept as many connections as possible each time the EPOLLIN event fires
        for the listening socket

     **************************************************************************/

    final bool handle ( Event event )
    {
        if (!this.terminated)
        {
            try
            {
                IConnectionHandler handler = this.getConnectionHandler();
                this.acceptConnection(handler);
            }
            catch
            {
                /* Catch an exception (or object) thrown by
                   getConnectionHandler() to prevent it from falling through
                   to the dispatcher which would unregister the server socket. */
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

            try
            {
                this.e.assertEx!(true)(!this.socket.shutdown(),
                                       "error on socket shutdown", __FILE__, __LINE__);
            }
            finally
            {
                this.socket.close();
            }
        }

        return this.terminated;
    }

    /**************************************************************************

        Returns:
            information interface to the connections pool

     **************************************************************************/

    abstract IPoolInfo poolInfo ( );

    /**************************************************************************

        Sets the limit of the number of connections. 0 disables the limitation.

        Notes:
            - If limit is set to something other than 0, limit connection
              handler objects will be created (so set it to a realistic value).
            - If not 0, limit must be at least the number of currently busy
              connections.

        Returns:
            connection limit

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

        Closes all connections and terminates the listener.

     **************************************************************************/

    abstract public void shutdown ( );

    /**************************************************************************

        Obtains a connection handler instance from the pool.

        Returns:
            connection handler

     **************************************************************************/

    abstract protected IConnectionHandler getConnectionHandler ( );

    /**************************************************************************

        Accepts the next pending incoming client connection and assigns it to
        a connection handler.

        Params:
            handler = handler to assign connection to

     **************************************************************************/

    private void acceptConnection ( IConnectionHandler handler )
    {
        try
        {
            handler.assign(this.socket);

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

    /**************************************************************************

        Accepts the next pending incoming client connection and closes it.

     **************************************************************************/

    private void declineConnection ( )
    {
        if (.close(.accept(this.socket.fileHandle, null, null))) // returns non-zero on failure
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

    TODO: try using the non-auto ctor pool, for template simplicity!

 ******************************************************************************/

public class SelectListener ( T : IConnectionHandler, Args ... ) : ISelectListener
{
    /**************************************************************************

        ObjectPool of connection handlers

     **************************************************************************/

    private const AutoCtorPool!(T, IConnectionHandler.FinalizeDg, Args) receiver_pool;

    /**************************************************************************

        Constructor

        Creates the server socket and registers it for incoming connections.

        Params:
            address    = server address
            port       = listening port
            dispatcher = SelectDispatcher instance to use
            args       = additional T constructor arguments, might be empty
            backlog    = (see ISelectListener ctor)

     **************************************************************************/

    public this ( char[] address, ushort port, Args args, int backlog = 32 )
    {
        super(address, port, backlog);

        this.receiver_pool = this.receiver_pool.newPool(&this.returnToPool, args);
    }

    /**************************************************************************

        Constructor

        Creates the server socket and registers it for incoming connections.

        Params:
            port       = listening port
            dispatcher = SelectDispatcher instance to use
            args       = additional T constructor arguments, might be empty
            backlog    = (see ISelectListener ctor)

     **************************************************************************/

    public this ( ushort port, Args args, int backlog = 32 )
    {
        super(port, backlog);

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
            this.receiver_pool.setLimit(limit);
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

        Minimizes the connection pool to n connections by deleting idle
        connection objects. If more than n connections are currently busy,
        all idle connections are deleted.

        Params:
            n = minimum number of connection objects to keep in the pool.

        Returns:
            the number of connection object in the pool after minimizing, which
            is the greater of n and the number of currently busy connections.

     **************************************************************************/

    public uint minimize ( uint n = 0 )
    out (still_existent)
    {
        assert (still_existent >= n);
    }
    body
    {
        uint limit = this.receiver_pool.limit,
        busy = this.receiver_pool.num_busy;

        scope (exit) this.receiver_pool.setLimit(limit);

        return this.receiver_pool.setLimit((n > busy)? n : busy);
    }

    /**************************************************************************

        Returns:
            information interface to the connections pool

     **************************************************************************/

    public IPoolInfo poolInfo ( )
    {
        return this.receiver_pool;
    }

    /**************************************************************************

        Closes all connections and terminates the listener.

     **************************************************************************/

    public void shutdown ( )
    {
        scope busy_connections = this.receiver_pool.new BusyItemsIterator;
        foreach ( busy_connection; busy_connections )
        {
            /* FIXME: calling finalize here will cause errors in any connection
             * handlers which are currently selected in epoll, as they will
             * subsequently attempt to finalize themselves again.
             *
             * In practice this is of little import however, as the whole server
             * is being shut down. It may be nice to find a clean way to avoid
             * this though.
             */
            busy_connection.finalize();
        }

        super.terminate();
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
}
