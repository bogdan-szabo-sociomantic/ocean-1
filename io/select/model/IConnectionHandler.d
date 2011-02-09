/*******************************************************************************

    Base class for a connection handler for use with SelectListener.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

*******************************************************************************/

module ocean.io.select.model.IConnectionHandler;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.SelectReader,
               ocean.io.select.protocol.SelectWriter;

private import ocean.io.select.model.ISelectListenerInfo;

private import ocean.io.select.EpollSelectDispatcher;
    
private import ocean.io.select.model.ISelectClient : IAdvancedSelectClient;

private import tango.net.device.Socket : Socket;

private import tango.io.model.IConduit : ISelectable;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Connection handler abstract base class.

*******************************************************************************/

abstract class IConnectionHandler : IAdvancedSelectClient.IFinalizer, IAdvancedSelectClient.IErrorReporter
{
    /***************************************************************************

        Local aliases for ISelectable and EpollSelectDispatcher.

    ***************************************************************************/

    public alias .ISelectable ISelectable;

    public alias .EpollSelectDispatcher EpollSelectDispatcher;


    /***************************************************************************

        Info interface to the select listener which owns this connection
        handler.

    ***************************************************************************/

    protected ISelectListenerInfo listener;


    /***************************************************************************

        Alias for a finalizer delegate, which can be specified externally and is
        called when the connection is shut down.

    ***************************************************************************/

    public alias void delegate ( typeof (this) ) FinalizeDg;


    /***************************************************************************

        Finalizer delegate which can be specified externally and is called when
        the connection is shut down.
    
    ***************************************************************************/

    private FinalizeDg finalize_dg;


    /***************************************************************************

        Alias for an error delegate, which can be specified externally and is
        called when a connection error occurs.
    
    ***************************************************************************/

    public alias void delegate ( Exception, IAdvancedSelectClient.EventInfo ) ErrorDg;


    /***************************************************************************

        Error delegate, which can be specified externally and is called when a
        connection error occurs.

    ***************************************************************************/

    private ErrorDg error_dg;


    /***************************************************************************

        Local aliases for SelectReader and SelectWriter.
    
    ***************************************************************************/

    public alias .SelectReader SelectReader;
    public alias .SelectWriter SelectWriter;


    /***************************************************************************

        SelectReader and SelectWriter used for asynchronous protocol i/o.

    ***************************************************************************/

    protected SelectReader reader;
    protected SelectWriter writer;


    /***************************************************************************

        Constructor.

        Opens a socket, sets it to non-blocking, disables Nagle algorithm.
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

    public this ( EpollSelectDispatcher dispatcher, ISelectListenerInfo listener_info, FinalizeDg finalize_dg, ErrorDg error_dg )
    {
        Socket socket = new Socket;
        socket.socket.noDelay(true).blocking(false);

        this.listener = listener_info;

        this.finalize_dg = finalize_dg;
        this.error_dg = error_dg;

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

    public typeof (this) assign ( void delegate ( ISelectable ) assign_to_conduit )
    {
    	this.init();

        this.assign_(assign_to_conduit);
        return this;
    }

    abstract protected void assign_ ( void delegate ( ISelectable ) );


    /***************************************************************************

        IAdvancedSelectClient.IFinalizer interface method. Called when this
        connection is shut down.
    
    ***************************************************************************/
    
    protected void finalize ( )
    {
        if ( this.finalize_dg )
        {
            this.finalize_dg(this);
        }
    }


    /***************************************************************************

        IAdvancedSelectClient.IErrorReporter interface method. Called when a
        connection error occurs.

        Params:
            exception = exception which caused the error
            event = epoll select event during which error occurred

    ***************************************************************************/

    protected void error ( Exception exception, IAdvancedSelectClient.EventInfo event )
    {
        if ( this.error_dg )
        {
            this.error_dg(exception, event);
        }
    }


    /***************************************************************************

        Initialises the reader and writer. Called whenever a connection is
        assigned, to ensure that the reader & writer states are clean.

    ***************************************************************************/
    
    private void init ( )
    {
        this.reader.init();
        this.writer.init();
    }
}

