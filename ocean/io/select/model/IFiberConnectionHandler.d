/*******************************************************************************

    Base class for a connection handler for use with SelectListener, using
    Fibers.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt, Gavin Norman

*******************************************************************************/

module ocean.io.select.model.IFiberConnectionHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol,
               ocean.io.select.protocol.fiber.FiberSelectReader,
               ocean.io.select.protocol.fiber.FiberSelectWriter,
               ocean.io.select.protocol.fiber.BufferedFiberSelectWriter;

private import ocean.io.select.model.IConnectionHandler;

private import ocean.io.select.fiber.SelectFiber;
private import ocean.core.MessageFiber : MessageFiberControl;

private import tango.net.device.Socket : Socket;

debug private import ocean.util.log.Trace;

/*******************************************************************************

    Fiber connection handler base class -- creates a socket and a fiber
    internally, but does not contain reader / writer instances.

*******************************************************************************/

abstract class IFiberConnectionHandlerBase : IConnectionHandler
{
    /***************************************************************************

        Default fiber stack size. 
    
    ***************************************************************************/
    
    public static size_t default_stack_size = 0x2000;
    
    /***************************************************************************

        Exception type alias. If handle() catches exceptions, it must rethrow
        these. 
    
    ***************************************************************************/

    protected alias SelectFiber.KilledException KilledException;
    
    /***************************************************************************

        Fiber to handle an single connection.

    ***************************************************************************/

    protected const SelectFiber fiber;

    /***************************************************************************

        Constructor
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll       = epoll select dispatcher
            stack_size  = fiber stack size
            finalize_dg = user-specified finalizer, called when the connection
                          is shut down
            error_dg    = user-specified error handler, called when a connection
                          error occurs

    ***************************************************************************/

    protected this ( EpollSelectDispatcher epoll,
                     size_t stack_size,
                     FinalizeDg finalize_dg = null,
                     ErrorDg error_dg = null )
    {
        super(finalize_dg, error_dg);
        
        this.fiber = new SelectFiber(epoll, &this.handleConnection_, stack_size);
    }
    
    /***************************************************************************

        Constructor, uses the default fiber stack size.
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll       = epoll select dispatcher
            finalize_dg = user-specified finalizer, called when the connection
                          is shut down
            error_dg    = user-specified error handler, called when a connection
                          error occurs
    
    ***************************************************************************/
    
    protected this ( EpollSelectDispatcher epoll,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, this.default_stack_size, finalize_dg, error_dg);
    }
    
    /**************************************************************************
    
        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)
    
     **************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        
        delete this.fiber;
    }
    
    /***************************************************************************
        
        Called by the select listener right after the client connection has been
        assigned.
    
        Note: fiber.start() may throw an exception if an exception instance is
        passed to the first suspend() call (e.g. the select reader encounters a
        socket error). In this case the select listener will call error() and
        finalize() which are usually called in handleConnection_() below.

    ***************************************************************************/

    public void handleConnection ( )
    in
    {
        assert (!this.fiber.running);
    }
    body
    {
        this.fiber.start();
    }
    
    /***************************************************************************
    
        Connection handler method. If it catches exceptions, it must rethrow
        those of type KilledException.
        
    ***************************************************************************/

    abstract protected void handle ( );
    
    /***************************************************************************

        Actual fiber method, started by handleConnection().
        
    ***************************************************************************/

    private void handleConnection_ ( )
    {
        try
        {
            debug ( ConnectionHandler ) Trace.formatln("[{}]: Handling connection", super.connection_id);

            this.handle();
        }
        catch ( Exception e )
        {
            super.error(e);
        }
        catch ( Object o )
        {
            debug ( ConnectionHandler ) Trace.formatln("[{}]: Caught object while handling connection", super.connection_id);
        }
        finally
        {
            super.finalize();
        }
    }
}


/*******************************************************************************

    Standard fiber connection handler class using the basic FiberSelectReader
    and FiberSelectWriter.

*******************************************************************************/

abstract class IFiberConnectionHandler : IFiberConnectionHandlerBase
{
    /***************************************************************************

        If true, a buffered writer is used by default. 
    
    ***************************************************************************/
    
    public static bool use_buffered_writer_by_default = false;
    
    /***************************************************************************

        Local aliases for SelectReader and SelectWriter.
    
    ***************************************************************************/
    
    public alias .FiberSelectReader SelectReader;
    public alias .FiberSelectWriter SelectWriter;
    
    /***************************************************************************
    
        SelectReader and SelectWriter used for asynchronous protocol i/o.

    ***************************************************************************/
    
    protected const SelectReader reader;
    protected const SelectWriter writer;
    
    /**************************************************************************/

    invariant
    {
        assert (this.reader.conduit is super.conduit);
        assert (this.reader.conduit is this.writer.conduit);
    }
    
    /***************************************************************************

        Constructor
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            stack_size      = fiber stack size
            buffered_writer = set to true to use the buffered writer 
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs
    
    ***************************************************************************/
    
    protected this ( EpollSelectDispatcher epoll,
                     size_t stack_size, bool buffered_writer,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, buffered_writer?
                        new BufferedFiberSelectWriter(super.conduit, super.fiber) :
                        new FiberSelectWriter(super.conduit, super.fiber),
                    finalize_dg, error_dg, stack_size);
    }
    
    /***************************************************************************

        Constructor, uses the default fiber stack size.
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            buffered_writer = set to true to use the buffered writer 
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs
    
    ***************************************************************************/
    
    protected this ( EpollSelectDispatcher epoll, bool buffered_writer,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, this.default_stack_size, buffered_writer, finalize_dg, error_dg);
    }
    
    /***************************************************************************

        Constructor, uses the default setting for buffered socket writing.
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            stack_size      = fiber stack size
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs
    
    ***************************************************************************/
    
    protected this ( EpollSelectDispatcher epoll, size_t stack_size,
                     FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        this(epoll, stack_size,
             this.use_buffered_writer_by_default, finalize_dg, error_dg);
    }
    
    /***************************************************************************

        Constructor, uses the default fiber stack size and the default setting
        for buffered socket writing.
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll           = epoll select dispatcher which this connection
                              should use for i/o
            finalize_dg     = user-specified finalizer, called when the
                              connection is shut down
            error_dg        = user-specified error handler, called when a
                              connection error occurs
    
    ***************************************************************************/
    
    protected this ( EpollSelectDispatcher epoll, FinalizeDg finalize_dg = null,
                     ErrorDg error_dg = null )
    {
        this(epoll, this.use_buffered_writer_by_default, finalize_dg, error_dg);
    }
    
    /***************************************************************************

        Constructor
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
        
        Params:
            epoll       = epoll select dispatcher which this connection should
                          use for i/o
            writer      = SelectWriter instance to use 
            finalize_dg = user-specified finalizer, called when the connection
                          is shut down
            error_dg    = user-specified error handler, called when a connection
                          error occurs
        
        Note that writer must be lazy because it must be newed _after_ the super
        constructor has been called.
        
    ***************************************************************************/

    private this ( EpollSelectDispatcher epoll, lazy SelectWriter writer,
                   FinalizeDg finalize_dg, ErrorDg error_dg, 
                   size_t stack_size )
    {
        super(epoll, stack_size, finalize_dg, error_dg);

        this.reader = new SelectReader(super.conduit, super.fiber);
        this.writer = writer;

        this.reader.error_reporter = this;
        this.writer.error_reporter = this;
    }
    
    /**************************************************************************
    
        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)
    
     **************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        
        delete this.reader;
        delete this.writer;
    }
    
    /**************************************************************************

        Called by IConnectionHandler.finalize(), in order to determine if an I/O
        error was reported for the connection conduit which made the connection
        automatically being closed.
        (See comment for IConnectionHandler.finalize() method.)
    
        Returns:
            true if an I/O error was reported to the reader or the writer for
            the connection conduit which made the connection automatically being
            closed or false otherwise.
        
     **************************************************************************/

    protected bool io_error ( )
    {
        return this.reader.io_error || this.writer.io_error;
    }
}

