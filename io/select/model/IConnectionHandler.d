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

        Alias for a finalizer delegate, which can be specified externally and is
        called when the connection is shut down.

    ***************************************************************************/

    public alias void delegate ( typeof (this) ) FinalizeDg;


    /***************************************************************************

        Finalizer delegate which can be specified externally and is called when
        the connection is shut down.
    
    ***************************************************************************/

    private FinalizeDg finalize_dg_ = null;


    /***************************************************************************

        Alias for an error delegate, which can be specified externally and is
        called when a connection error occurs.
    
    ***************************************************************************/

    public alias void delegate ( Exception, IAdvancedSelectClient.EventInfo ) ErrorDg;


    /***************************************************************************

        Error delegate, which can be specified externally and is called when a
        connection error occurs.

    ***************************************************************************/

    private ErrorDg error_dg_ = null;


    /***************************************************************************

        Constructor
        
        Params:
            error_dg_    = optional user-specified error handler, called when a
                           connection error occurs

     ***************************************************************************/
    
    public this ( ErrorDg error_dg_ = null )
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

    public this ( FinalizeDg finalize_dg_ = null, ErrorDg error_dg_ = null )
    {
        this.finalize_dg_ = finalize_dg_;
        this.error_dg_ = error_dg_;
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

        Called by the SelectListener when an incoming connection needs to be
        accepted. A delegate is passed as a parameter, which should be called
        with the conduit which is to handle the incoming connection. The
        decision of which conduit (ie the reader or the writer) should accept
        the connection is left to the implementing class.

        Params:
            assign_to_conduit = delegate passed from SelectListener which
                accepts the incoming connection with the conduit passed to it

    ***************************************************************************/

    abstract public void assign ( void delegate ( ISelectable ) );

    /***************************************************************************

        IAdvancedSelectClient.IFinalizer interface method. Called when this
        connection is shut down.
    
    ***************************************************************************/
    
    public void finalize ( )
    {
        if ( this.finalize_dg_ )
        {
            this.finalize_dg_(this);
        }
    }
    
    /***************************************************************************

        IAdvancedSelectClient.IErrorReporter interface method. Called when a
        connection error occurs.

        Params:
            exception = exception which caused the error
            event = epoll select event during which error occurred

    ***************************************************************************/

    public void error ( Exception exception, IAdvancedSelectClient.EventInfo event )
    {
        if ( this.error_dg_ )
        {
            this.error_dg_(exception, event);
        }
    }
}

