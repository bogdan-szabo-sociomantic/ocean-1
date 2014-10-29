/*******************************************************************************

    Base class for a connection handler for use with SelectListener.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

*******************************************************************************/

module ocean.net.server.connection.IConnectionHandler;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.EpollSelectDispatcher;

import ocean.net.server.connection.IConnectionHandlerInfo;
import ocean.io.select.client.model.ISelectClient : IAdvancedSelectClient;

import ocean.io.select.protocol.generic.ErrnoIOException: SocketError;

import ocean.sys.socket.IPSocket;
import ocean.sys.socket.AddressIPSocket;

import ocean.io.device.IODevice: IInputDevice, IOutputDevice;

import ocean.text.convert.Layout;

import tango.io.model.IConduit: ISelectable;

debug ( ConnectionHandler ) import tango.util.log.Trace;


/*******************************************************************************

    Connection handler abstract base class.

*******************************************************************************/

abstract class IConnectionHandler : IConnectionHandlerInfo,
    IAdvancedSelectClient.IErrorReporter
{
    /***************************************************************************

        Object pool index.

    ***************************************************************************/

    public uint object_pool_index;

    /***************************************************************************

        Local aliases to avoid public imports.

    ***************************************************************************/

    public alias .AddressIPSocket!() AddressIPSocket;

    public alias .EpollSelectDispatcher EpollSelectDispatcher;

    protected alias IAdvancedSelectClient.Event Event;

    /***************************************************************************

        Client connection socket, exposed to subclasses downcast to Conduit.

    ***************************************************************************/

    protected const AddressIPSocket socket;

    /***************************************************************************

        SocketError instance to throw on error and query the current socket
        error status.

    ***************************************************************************/

    protected const SocketError socket_error;

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

        this.socket = new AddressIPSocket;

        this.socket_error = new SocketError(this.socket);

        debug this.connection_id = connection_count++;
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    protected override void dispose ( )
    {
        this.finalize_dg_ = null;
        this.error_dg_    = null;

        delete this.socket;
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

        Returns:
            true if a client connection is currently established or false if
            not.

    ***************************************************************************/

    public bool connected ( )
    {
        return this.socket.fileHandle >= 0;
    }

    /***************************************************************************

        IConnectionHandlerInfo method.

        Returns:
            informational interface to the socket used by this connection
            handler

    ***************************************************************************/

    public IAddressIPSocketInfo socket_info ( )
    {
        return this.socket;
    }

    /***************************************************************************

        Accepts a pending connection from listening_socket and assigns it to the
        socket of this instance.

        Params:
            listening_socket = the listening server socket for which a client
                               connection is pending

    ***************************************************************************/

    public void assign ( ISelectable listening_socket )
    in
    {
        assert (!this.connected, "client connection was open before assigning");
    }
    body
    {
        debug ( ConnectionHandler ) Trace.formatln("[{}]: New connection", this.connection_id);

        if (this.socket.accept(listening_socket, true) < 0)
        {
            this.error(this.socket_error.setSock("error accepting connection", __FILE__, __LINE__));
        }
    }

    /***************************************************************************

        Called by the select listener right after the client connection has been
        assigned.
        If ths method throws an exception, error() and finalize() will be called
        by the select listener.

    ***************************************************************************/

    public abstract void handleConnection ( );

    /***************************************************************************

        Must be called by the subclass when finished handling the connection.
        Will be automatically called by the select listener if assign() or
        handleConnection() throws an exception.

        The closure of the socket after handling a connection is quite
        sensitive. If a connection has actually been assigned, the socket must
        be shut down *unless* an I/O error has been reported for the socket
        because then it will already have been shut down automatically. The
        abstract io_error() method is used to determine whether the an I/O error
        was reported for the socket or not.

    ***************************************************************************/

    public void finalize ( )
    {
        if ( this.connected )
        {
            debug ( ConnectionHandler ) Trace.formatln("[{}]: Closing connection", this.connection_id);

            if (this.io_error) if (this.socket.shutdown())
            {
                this.error(this.socket_error.setSock("error closing connection", __FILE__, __LINE__));
            }

            this.socket.close();
        }

        if ( this.finalize_dg_ ) try
        {
            this.finalize_dg_(this);
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

        Formats information about the connection into the provided buffer. This
        method is called from the SelectListener in order to log information
        about the state of all connections in the pool.

        We format the following here:
            * the file descriptor of the socket of this connection
            * the remote ip and port of the socket
            * whether an I/O error has occurred for the socket since the last
              call to assign()

        Params:
            buf = buffer to format into

    ***************************************************************************/

    public void formatInfo ( ref char[] buf )
    {
        Layout!(char).print(buf, "fd={}, remote={}:{}, ioerr={}",
            this.socket_info.fileHandle, this.socket_info.address,
            this.socket_info.port, this.io_error);
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
