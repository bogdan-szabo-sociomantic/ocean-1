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

private import ocean.io.select.EpollSelectDispatcher;
    
private import ocean.io.select.model.ISelectClient : IAdvancedSelectClient;

private import tango.io.model.IConduit : ISelectable;

private import tango.net.device.Socket;

debug private import ocean.util.log.Trace;



/*******************************************************************************

    Connection handler abstract base class.

*******************************************************************************/

abstract class IConnectionHandler : IAdvancedSelectClient.IFinalizer, IAdvancedSelectClient.IErrorReporter
{
    /***************************************************************************

        Object pool index.

    ***************************************************************************/

    public uint object_pool_index;

    /***************************************************************************

        Local aliases to avoid public imports.

    ***************************************************************************/

    public alias .ISelectable ISelectable;

    public alias .EpollSelectDispatcher EpollSelectDispatcher;
    
    protected alias IAdvancedSelectClient.Event Event;
    
    /***************************************************************************

        Client connection socket, exposed to subclasses downcast to Conduit.

    ***************************************************************************/

    private const Socket socket;
    
    protected const ISelectable conduit;
    
    /***************************************************************************

        Flag that tells whether finalize() should close the client connection
        socket. 

    ***************************************************************************/

    private bool connection_open = false;
    
    /***************************************************************************

        Alias for a finalizer delegate, which can be specified externally and is
        called when the connection is shut down.

    ***************************************************************************/

    public alias void delegate ( typeof (this) instance ) FinalizeDg;

    /***************************************************************************

        Finalizer delegate which can be specified externally and is called when
        the connection is shut down.
    
    ***************************************************************************/

    private FinalizeDg finalize_dg_ = null;

    /***************************************************************************

        Alias for an error delegate, which can be specified externally and is
        called when a connection error occurs.
    
    ***************************************************************************/

    public alias void delegate ( Exception exception, Event event ) ErrorDg;

    /***************************************************************************

        Error delegate, which can be specified externally and is called when a
        connection error occurs.

    ***************************************************************************/

    private ErrorDg error_dg_ = null;

    /***************************************************************************
    
        Instance id number in debug builds.
    
    ***************************************************************************/
    
    debug
    {
        static private uint connection_count;
        public uint connection_id;
    }

    /***************************************************************************

        Constructor
        
        Params:
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

     ***************************************************************************/
    
    protected this ( ErrorDg error_dg_ = null )
    {
        this(null, error_dg_);
    }
    
    /***************************************************************************

        Constructor
        
        Params:
            finalize_dg_ = optional user-specified finalizer, called when the
                           connection is shut down
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

    ***************************************************************************/

    protected this ( FinalizeDg finalize_dg_ = null, ErrorDg error_dg_ = null )
    {
        this.finalize_dg_ = finalize_dg_;
        this.error_dg_ = error_dg_;

        this.conduit = this.socket = new Socket;
        
        debug this.connection_id = connection_count++;
    }
    
    /***************************************************************************

        Sets the finalizer callback delegate which is called when the
        connection is shut down. Setting to null disables the finalizer.
        
        Params:
            finalize_dg_ = finalizer callback delegate
        
        Returns:
            finalize_dg_
        
    ***************************************************************************/

    public FinalizeDg finalize_dg ( FinalizeDg finalize_dg_ )
    {
        return this.finalize_dg_ = finalize_dg_;
    }
    
    /***************************************************************************

        Sets the error handler callback delegate which is called when a
        connection error occurs. Setting to null disables the error handler.
        
        Params:
            error_dg_ = error callback delegate
        
        Returns:
            error_dg_
        
    ***************************************************************************/

    public ErrorDg error_dg ( ErrorDg error_dg_ )
    {
        return this.error_dg_ = error_dg_;
    }

    /***************************************************************************
        
        Invokes assign_to_conduit with the connection socket of this instance
        and starts the handler coroutine.
    
        Params:
            assign_to_conduit = delegate passed from SelectListener which
                accepts the incoming connection with the conduit passed to it
    
    ***************************************************************************/
    
    public void assign ( void delegate ( Socket ) assign_to_conduit )
    in
    {
        assert (!this.connection_open, "client connection was open before assigning");
    }
    body
    {
        debug ( ConnectionHandler ) Trace.formatln("[{}]: New connection", this.connection_id);

        assign_to_conduit(this.socket);
        
        this.connection_open = true;
    }
    
    /***************************************************************************
        
        Called by the select listener right after the client connection has been
        assigned.
        If ths method throws an exception, error() and finalize() will be called
        by the select listener.

    ***************************************************************************/

    public abstract void handleConnection ( );
    
    /***************************************************************************

        IAdvancedSelectClient.IFinalizer interface method. Must be called by the
        subclass when finished handling the connection. Will be automatically
        called by the select listener if assign() or handleConnection() throws
        an exception.
        
        The closure of the socket after handling a connection is quite
        sensitive. If a connection has actually been assigned, the socket must
        be closed *unless* an I/O error has been reported for the socket because
        then it will already have been closed automatically. The abstract
        io_error() method is used to determine whether the an I/O error was
        reported for the socket or not.
        
    ***************************************************************************/
    
    public void finalize ( )
    {
        try
        {
            try
            {
                if ( this.connection_open && !this.io_error )
                {
                    debug ( ConnectionHandler ) Trace.formatln("[{}]: Closing connection", this.connection_id);
                    
                    this.socket.shutdown().close();
                }
            }
            finally
            {
                this.connection_open = false;
                
                if ( this.finalize_dg_ )
                {
                    this.finalize_dg_(this);
                }
            }
        }
        catch ( Exception e )
        {
            this.error(e);
        }
    }
    
    /***************************************************************************

        IAdvancedSelectClient.IErrorReporter interface method. Called when a
        connection error occurs.

        Params:
            exception = exception which caused the error
            event = epoll select event during which error occurred, if any

    ***************************************************************************/

    public void error ( Exception exception, Event event = Event.init )
    {
        debug ( ConnectionHandler ) try if ( this.io_error )
        {
            Trace.formatln("[{}]: Caught io exception while handling connection: '{}' @ {}:{}",
                    this.connection_id, exception.msg, exception.file, exception.line);
        }
        else
        {
            debug ( ConnectionHandler ) Trace.formatln("[{}]: Caught non-io exception while handling connection: '{}' @ {}:{}",
                    this.connection_id, exception.msg, exception.file, exception.line);
        }
        catch { /* Theoretically io_error() could throw. */ }

        if ( this.error_dg_ )
        {
            this.error_dg_(exception, event);
        }
    }
    
    /***************************************************************************

        Tells whether an I/O error has been reported for the socket since the
        last assign() call.
        
        Returns:
            true if an I/O error has been reported for the socket or false
            otherwise.
        
    ***************************************************************************/
    
    protected abstract bool io_error ( ); 
}
