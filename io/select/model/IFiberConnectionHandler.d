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
               ocean.io.select.protocol.fiber.FiberSelectWriter;

private import ocean.io.select.model.IConnectionHandler;

private import ocean.io.select.protocol.fiber.model.KillableFiber;

private import tango.net.device.Socket : Socket;

private import tango.io.Stdout;

/******************************************************************************/

class IFiberConnectionHandler : IConnectionHandler
{
   /***************************************************************************

        Local aliases for SelectReader and SelectWriter.
    
    ***************************************************************************/
    
    public alias .FiberSelectReader SelectReader;
    public alias .FiberSelectWriter SelectWriter;
    
    /***************************************************************************
    
        SelectReader and SelectWriter used for asynchronous protocol i/o.
    
    ***************************************************************************/
    
    protected SelectReader reader;
    protected SelectWriter writer;
    
    private KillableFiber fiber;
    
    /**************************************************************************/
    
    invariant
    {
        assert (this.reader.conduit is this.writer.conduit);
    }

    /***************************************************************************

        Constructor
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            epoll = epoll select dispatcher which this connection should
                use for i/o
            finalize_dg = user-specified finalizer, called when the connection
                is shut down
            error_dg = user-specified error handler, called when a connection
                error occurs
    
    ***************************************************************************/
    
    public this ( EpollSelectDispatcher epoll, FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        super(finalize_dg, error_dg);

        Socket socket = new Socket;
        socket.socket.noDelay(true).blocking(false);

        this.fiber = new KillableFiber(&this.handleConnection, 0x2000);
        
        this.reader = new SelectReader(socket, this.fiber, epoll);
        this.writer = new SelectWriter(socket, this.fiber, epoll);

        this.reader.finalizer = this;
        this.writer.finalizer = this;
        
        this.reader.error_reporter = super;
        this.writer.error_reporter = super;
    }
    
    /***************************************************************************
        
        Invokes assign_to_conduit with the connection socket of this instance
        and starts the handler coroutine.
    
        Params:
            assign_to_conduit = delegate passed from SelectListener which
                accepts the incoming connection with the conduit passed to it
    
    ***************************************************************************/
    
    public void assign ( void delegate ( ISelectable ) assign_to_conduit )
    in
    {
        assert (!this.fiber.running);
    }
    body
    {
        assign_to_conduit(this.reader.conduit);
        
        this.fiber.start();
    }
    
    /***************************************************************************
    
        Finalizer callback for reader and writer; resumes the fiber after a
        read or write operation has finished.
            
    ***************************************************************************/

    override void finalize ( )
    in
    {
        assert (!this.fiber.running);
    }
    body
    {
        if (this.fiber.waiting)
        {
            this.fiber.resume();
        }
    }
    
    /***************************************************************************
    
        Error callback for reader and writer; aborts connection handling when a
        read or write operation failed.
            
    ***************************************************************************/

    override void error ( Exception exception, IAdvancedSelectClient.EventInfo event )
    {
        scope (exit) if (this.fiber.waiting)
        {
            this.fiber.kill();
            super.finalize();
        }
        
        super.error(exception, event);
    }
    
    /***************************************************************************
    
        Connection handler method
        
    ***************************************************************************/

    abstract protected void handle ( );
    
    /**************************************************************************

        Resumes the fiber coroutine.
        
        In:
            The fiber must be waiting (suspended/ceding).
    
     **************************************************************************/
    
    protected void resume ( )
    in
    {
        assert (this.fiber.waiting);
    }
    body
    {
        this.fiber.resume();
    }
    
    /**************************************************************************

        Resumes the fiber coroutine.
        
        In:
            The fiber must be running (called/executing).
    
     **************************************************************************/

    protected void suspend ( )
    in
    {
        assert (this.fiber.running);
    }
    body
    {
        this.fiber.suspend();
    }
    
    /***************************************************************************
        
        Actual fiber method, started by assign().
    
    ***************************************************************************/
    
    private void handleConnection ( )
    {
        try
        {
            this.handle();
            this.closeConnection();
            
            super.finalize();
        }
        catch (KillableFiber.KilledException) {} 
        catch
        {
            super.finalize();
        }
    }

    /**************************************************************************

        Closes the client connection socket.
    
     **************************************************************************/
    
    private void closeConnection ( )
    in
    {
        assert (cast (Socket) this.writer.conduit !is null, "conduit is not a socket");
    }
    body
    {
        (cast (Socket) this.writer.conduit).shutdown().close();
    }
}
