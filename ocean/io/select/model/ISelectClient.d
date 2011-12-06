/******************************************************************************

    Base class for registrable client objects for the SelectDispatcher

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    Contains the three things that the SelectDispatcher needs:
        1. the I/O device instance
        2. the I/O events to register the device for
        3. the event handler to invocate when an event occured for the device
        
    In addition a subclass may override finalize(). When handle() returns false
    or throws an Exception, the ISelectClient instance is unregistered from the
    SelectDispatcher and finalize() is invoked. 
    
 ******************************************************************************/

module ocean.io.select.model.ISelectClient;



/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.sys.linux.epoll: EPOLLIN, EPOLLOUT, EPOLLPRI,
                                      EPOLLONESHOT, EPOLLET,
                                      EPOLLHUP, EPOLLERR;

private const EPOLLRDHUP = 0x2000;

private import tango.io.model.IConduit: ISelectable;

private import ocean.time.timeout.model.ITimeoutClient,
               ocean.time.timeout.model.IExpiryRegistration: IExpiryRegistration;

private import ocean.core.Array: concat, append;

private import tango.stdc.posix.sys.socket: getsockopt, SOL_SOCKET, SO_ERROR, socklen_t;

private import tango.stdc.string: strlen;

debug private import ocean.util.log.Trace;



/******************************************************************************

    ISelectClient abstract class

 ******************************************************************************/

abstract class ISelectClient : ITimeoutClient
{
    public alias .ISelectable ISelectable;

    public enum Event
    {
        None            = 0,
        Read            = EPOLLIN,
        UrgentRead      = EPOLLPRI,
        Write           = EPOLLOUT,
        EdgeTriggered   = EPOLLET,
        OneShot         = EPOLLONESHOT,
        ReadHangup      = EPOLLRDHUP,
        Hangup          = EPOLLHUP,
        Error           = EPOLLERR
    }
    
    
    /**************************************************************************

        I/O device instance

        Note: Conforming to the name convention used in tango.io.selector, the
        ISelectable instance is named "conduit" although ISelectable and
        IConduit are distinct from each other. However, in most application
        cases the provided instance will originally implement both ISelectable
        and IConduit (as, for example, tango.io.device.Device and
        tango.net.device.Socket). 

     **************************************************************************/

    public const ISelectable conduit;
    
    /**************************************************************************

        Connection time out in microseconds. Effective only when used with an
        EpollSelectDispatcher which has timeouts enabled. A value of 0 has no
        effect.

     **************************************************************************/

    public ulong timeout_us = 0;
    
    /**************************************************************************

        Timeout expiry registration instance
    
     **************************************************************************/

    private IExpiryRegistration expiry_registration_;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit     = I/O device instance
    
     **************************************************************************/

    protected this ( ISelectable conduit )
    in
    {
        debug (ISelectClient) assert (conduit !is null, this.id ~ ": conduit is null");
        else  assert (conduit !is null, typeof (this).stringof ~ ": conduit is null");
    }
    body
    {
        this.conduit = conduit;
    }
    
    /**************************************************************************

        Sets the timeout manager expiry registration.
        
        Params:
            expiry_registration_ = timeout manager expiry registration
            
        Returns:
            timeout manager expiry registration
    
     **************************************************************************/

    public IExpiryRegistration expiry_registration ( IExpiryRegistration expiry_registration_ )
    {
        return this.expiry_registration_ = expiry_registration_;
    }
    
    /***************************************************************************

        Registers this client with the timeout manager.
        On timeout this client will automatically be unregistered.
        This client must currently not be registered.
        
        Returns:
            true if registered or false if timeout_us is 0.
        
    ***************************************************************************/

    public bool registerTimeout ( )
    {
        return (this.expiry_registration_ !is null)?
                    this.expiry_registration_.register(this.timeout_us) : false;
    }
    
    /***************************************************************************

        Unregisters the this client from the timeout manager.
        If a client is currently not registered, nothing is done.
        
        Must not be called from within timeout().
        
        Returns:
            true on success or false if this client was not registered.
        
    ***************************************************************************/

    public bool unregisterTimeout ( )
    {
        return (this.expiry_registration_ !is null)?
                    this.expiry_registration_.unregister : false;
    }
    
    /***************************************************************************

        Returns:
            true if this client has timed out or false otherwise.
    
    ***************************************************************************/

    public bool timed_out ( )
    {
        return (this.expiry_registration_ !is null)?
                    this.expiry_registration_.timed_out : false;
    }

    /**************************************************************************

        Returns the I/O events to register the device for
        
        Returns:
             the I/O events to register the device for
    
     **************************************************************************/

    abstract public Event events ( );
    
    /**************************************************************************

        I/O event handler
        
        Params:
             event   = identifier of I/O event that just occured on the device
             
        Returns:
            true if the handler should be called again on next event occurrence
            or false if this instance should be unregistered from the
            SelectDispatcher.
    
     **************************************************************************/

    abstract public bool handle ( Event event );

    /**************************************************************************

        Timeout method, called after a timeout occurs in the SelectDispatcher
        eventLoop. Intended to be overloaded by a subclass if required.

     **************************************************************************/

    public void timeout ( ) { }

    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher. Intended to be overloaded by a subclass if required.
        
     **************************************************************************/

    public void finalize ( ) { }
    
    /**************************************************************************

        Error reporting method, called when an Exception is caught from
        handle(). Calls the error_() method, which should be overloaded by a
        subclass if required.

        Note that this method will catch all exceptions thrown by the error_()
        method. This is to prevent unhandled exceptions flying out of the select
        dispatcher and brining down the event loop.

        Params:
            exception: Exception thrown by handle()
            event:     Seletor event while exception was caught
        
     **************************************************************************/

    final public void error ( Exception exception, Event event = Event.None )
    {
        try
        {
            this.error_(exception, event);
        }
        catch ( Exception e )
        {
            // Note: this should *never* happen! In case it ever does, here's
            // a helpful printout to notify the application programmer.
            debug Trace.formatln("Very bad: Exception thrown from inside ISelectClient.error() delegate! -- {} ({}:{})", e.msg, e.file, e.line);
        }
    }

    protected void error_ ( Exception exception, Event event ) { }
    
    /**************************************************************************

        Method to get string formatted information about a connection (for
        example the address and port of a socket connection). Intended to be
        overloaded by a subclass if required.

        Params:
            buffer = string to receive formatted connection information
        
     **************************************************************************/

    public void connectionInfo ( ref char[] buffer ) { }
    
    /**************************************************************************

        Obtains the socket error reported for conduit. Returns normally if the
        conduit is actually not a socket.
        
        Params:
            errnum = output of system error code of the reported socket error
            
        Returns:
            true if an error code could be obtained and is different from 0 or
            false otherwise
        
     **************************************************************************/

    public bool getSocketError ( out int errnum )
    {
        socklen_t len = errnum.sizeof;
        
        bool ok = !getsockopt(this.conduit.fileHandle, SOL_SOCKET, SO_ERROR, &errnum, &len);
        
        return ok && errnum;
    }
    
    /**************************************************************************

        Obtains the socket error reported for conduit and the corresponding
        error message. Returns normally if the conduit is actually not a socket.
        
        Params:
            errnum = output of system error code of the reported socket error
            errmsg = error message output, will remain untouched if the return
                     value is false
            msg    = message strings to concatenate and prepend to the error
                     message
            
        Returns:
            true if an error code could be obtained and is different from 0 or
            false otherwise
        
     **************************************************************************/

    public bool getSocketErrorT ( T ... ) ( out int errnum, ref char[] errmsg, T msg )
    {
        bool have_errnum = this.getSocketError(errnum);
        
        if (have_errnum)
        {
            char[0x100] buf;
            
            char* errmsg_ = strerror_r(errnum, buf.ptr, buf.length);
            
            errmsg.concat(msg);
            errmsg.append(errmsg_[0 .. strlen(errmsg_)]);
        }
        
        return have_errnum;
    }
    
    alias getSocketErrorT!(char[]) getSocketError;
    
    /**************************************************************************

        Returns an identifier string of this instance
        
        Returns:
             identifier string of this instance
    
     **************************************************************************/

    debug (ISelectClient) abstract public char[] id ( );
}

/******************************************************************************

    IAdvancedSelectClient abstract class

    Provides a set of interfaces which can be implemented by classes which
    desire notification of various events in the select client, and a set of
    corresponding methods which allow the user to pass an instance of these
    interfaces to an instance of this class:
        * IFinalizer interface, set by the finalizer() method, called when a
          select client is unregistered.
        * IErrorReporter interface, set by the error_reporter() method, called
          when an error occurs while handling a select client.
        * ITimeoutReporter interface, set by the timeout_reporter() method,
          called when a timeout occurs while handling a select client.
        * IConnectionInfo interface, set by the connection_info() method, called
          in debug(ISelectClient) mode when the selector wishes to get a string
          containing information about the connection a select client is using.

 ******************************************************************************/

abstract class IAdvancedSelectClient : ISelectClient
{
    /**************************************************************************/

    interface IFinalizer
    {
        void finalize ( );
    }
    
    /**************************************************************************/

    interface IErrorReporter
    {
        void error ( Exception exception, Event event = Event.None );
    }

    /**************************************************************************/

    interface IConnectionInfo
    {
        void connectionInfo ( ref char[] buffer );
    }

    /**************************************************************************/

    interface ITimeoutReporter
    {
        void timeout ( );
    }

    /**************************************************************************

        Interface instances

     **************************************************************************/
    
    private IFinalizer       finalizer_        = null;
    private IErrorReporter   error_reporter_   = null;
    private IConnectionInfo  connection_info_  = null;
    private ITimeoutReporter timeout_reporter_ = null;
    
    /**************************************************************************

        Constructor

        Params:
            conduit     = I/O device instance

     **************************************************************************/
    
    protected this ( ISelectable conduit )
    {
        super(conduit);
    }
    
    /**************************************************************************

        Sets the Finalizer. May be set to null to disable finalizing.
        
        Params:
            finalizer_ = IFinalizer instance
    
     **************************************************************************/
    
    public void finalizer ( IFinalizer finalizer_ )
    {
        this.finalizer_ = finalizer_;
    }
    
    /**************************************************************************

        Sets the TimeoutReporter. May be set to null to disable timeout
        reporting.
    
        Params:
            timeout_reporter_ = ITimeoutReporter instance
    
     **************************************************************************/
    
    public void timeout_reporter ( ITimeoutReporter timeout_reporter_ )
    {
        this.timeout_reporter_ = timeout_reporter_;
    }
    
    /**************************************************************************
    
        Sets the Error Reporter. May be set to null to disable error reporting.
        
        Params:
            error_reporter_ = IErrorReporter instance
    
     **************************************************************************/
    
    public void error_reporter ( IErrorReporter error_reporter_ )
    {
        this.error_reporter_ = error_reporter_;
    }
    
    /**************************************************************************
    
        Sets the Connection Info. May be set to null to disable fetching of
        connection info.
        
        Params:
            connection_info_ = IConnectionInfo instance
    
     **************************************************************************/
    
    public void connection_info ( IConnectionInfo connection_info_ )
    {
        this.connection_info_ = connection_info_;
    }

    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher.
    
     **************************************************************************/
    
    public override void finalize ( )
    {
        if (this.finalizer_ !is null)
        {
            this.finalizer_.finalize();
        }
    }

    /**************************************************************************

        Error reporting method, called when an Exception is caught from
        super.handle().
        
        Params:
            exception: Exception thrown by handle()
            event:     Selector event while exception was caught
        
     **************************************************************************/
    
    override protected void error_ ( Exception exception, Event event )
    {
        if (this.error_reporter_)
        {
            this.error_reporter_.error(exception, event);
        }
    }
    
    /**************************************************************************
    
        Connection info fetching method.
    
        Params:
            buffer = string buffer to receive formatted connection info
        
     **************************************************************************/
    
    override public void connectionInfo ( ref char[] buffer )
    {
        if (this.connection_info_)
        {
            this.connection_info_.connectionInfo(buffer);
        }
    }

    /**************************************************************************

        Timeout method, called after this a timeout has occurred in the
        SelectDispatcher.
    
     **************************************************************************/
    
    override public void timeout ( )
    {
        if (this.timeout_reporter_)
        {
            this.timeout_reporter_.timeout();
        }
    }
}

/******************************************************************************

    Obtains the system error message corresponding to errnum (reentrant/
    thread-safe version of strerror()).
    
    Note: This is the GNU (not the POSIX) version of strerror_r().
    
    @see http://www.kernel.org/doc/man-pages/online/pages/man3/strerror.3.html
    
    "The GNU-specific strerror_r() returns a pointer to a string containing the
     error message.  This may be either a pointer to a string that the function
     stores in buf, or a pointer to some (immutable) static string (in which case
     buf is unused).  If the function stores a string in buf, then at most buflen
     bytes are stored (the string may be truncated if buflen is too small) and
     the string always includes a terminating null byte."
    
    Tries have shown that buffer may actually not be populated.
    
    Params:
        errnum = error number
        buffer = error message destination buffer (may or may not be populated)
        buflen = destination buffer length
    
    Returns:
        a NUL-terminated string containing the error message

******************************************************************************/

private extern (C) char* strerror_r ( int errnum, char* buffer, size_t buflen );

