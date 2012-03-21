/*******************************************************************************

    Base class for a connection handler for use with SelectListener.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

*******************************************************************************/

module ocean.io.select.model.IChainConnectionHandler;

private import ocean.io.select.model.IConnectionHandler;

private import ocean.io.select.protocol.chain.ChainSelectReader,
               ocean.io.select.protocol.chain.ChainSelectWriter;

private import tango.net.device.Socket;

/******************************************************************************/

deprecated class IChainConnectionHandler : IConnectionHandler
{
    /***************************************************************************

        Local aliases for SelectReader and SelectWriter.
    
    ***************************************************************************/
    
    public alias .ChainSelectReader SelectReader;
    public alias .ChainSelectWriter SelectWriter;
    
    
    /***************************************************************************
    
        SelectReader and SelectWriter used for asynchronous protocol i/o.
    
    ***************************************************************************/
    
    protected SelectReader reader;
    protected SelectWriter writer;


    /***************************************************************************

        Constructor.
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            dispatcher = epoll select dispatcher which this connection should
                use for i/o
            finalize_dg = user-specified finalizer, called when the connection
                is shut down
            error_dg = user-specified error handler, called when a connection
                error occurs
    
    ***************************************************************************/
    
    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalize_dg, ErrorDg error_dg )
    {
        super(finalize_dg, error_dg);

        Socket socket = new Socket;
        socket.socket.noDelay(true).blocking(false);

        this.reader = new SelectReader(socket, dispatcher);
        this.reader.finalizer = this;
        this.reader.error_reporter = this;
    
        this.writer = new SelectWriter(socket, dispatcher);
        this.writer.finalizer = this;
        this.writer.error_reporter = this;
    }


    /***************************************************************************

        Called by the SelectListener when an incoming connection needs to be
        accepted. A delegate is passed as a parameter, which should be called
        with the conduit which is to handle the incoming connection. The
        decision of which conduit (ie the reader or the writer) should accept
        the connection is left to the deriving class (via the abstract assign_()
        method).

        The connection handler instance is always reset before the connection
        is accepted. In the case where the previous connection this instance
        handled ended normally, this initialisation is not strictly necessary.
        However in the case where the previous connection was terminated
        prematurely, the initialisation is needed.

        Params:
            assign_to_conduit = delegate passed from SelectListener which
                accepts the incoming connection with the conduit passed to it

    ***************************************************************************/

    public void assign ( void delegate ( ISelectable conduit ) assign_to_conduit )
    {
        this.init();
        this.assign_(assign_to_conduit);
    }

    abstract protected void assign_ ( void delegate ( ISelectable ) );


    /***************************************************************************

        Initialises the reader and writer. Called whenever a connection is
        assigned, to ensure that the reader & writer states are clean.
        
        FIXME: Looks like it isn't called from anywhere...
        
    ***************************************************************************/
    
    private void init ( )
    {
        this.reader.init();
        this.writer.init();
    }
}

