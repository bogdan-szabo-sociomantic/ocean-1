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

private import ocean.io.select.protocol.fiber.model.MessageFiber;

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
    
    private MessageFiber fiber_;
    
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

        this.fiber_ = new MessageFiber(&this.handleConnection, 0x2000);
        
        this.reader = new SelectReader(socket, this.fiber_, epoll);
        this.writer = new SelectWriter(socket, this.fiber_, epoll);
        
        this.reader.error_reporter = this;
        this.writer.error_reporter = this;
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
        assert (!this.fiber_.running);
    }
    body
    {
        assign_to_conduit(this.reader.conduit);
        
        this.fiber_.start();
    }
    
    /***************************************************************************
    
        Connection handler method
        
    ***************************************************************************/

    abstract protected void handle ( );
    
    /***************************************************************************
    
        Returns:
            the fiber
        
    ***************************************************************************/

    protected MessageFiberControl fiber ( )
    {
        return this.fiber_;
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
        }
        catch {} 
        finally
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
