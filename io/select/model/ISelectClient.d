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

private import ocean.io.select.timeout.ExpiryRegistry;

private import tango.sys.linux.epoll: EPOLLIN, EPOLLOUT, EPOLLPRI,
                                      EPOLLONESHOT, EPOLLET,
                                      EPOLLHUP, EPOLLERR;

private const EPOLLRDHUP = 0x2000;

private import tango.io.model.IConduit: ISelectable;

private import ocean.core.Array: concat, append;

private import tango.stdc.posix.sys.socket: getsockopt, SOL_SOCKET, SO_ERROR, socklen_t;

private import tango.stdc.string: strlen;

debug private import tango.util.log.Trace;



/******************************************************************************

    ISelectClient abstract class

 ******************************************************************************/

abstract class ISelectClient
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

        Flag telling whether this client is registered with the select
        dispatcher.

     **************************************************************************/

    public bool registered = false;
    
    /**************************************************************************

        I/O device instance

        Note: Conforming to the name convention used in tango.io.selector, the
        ISelectable instance is named "conduit" although ISelectable and
        IConduit are distinct from each other. However, in most application
        cases the provided instance will originally implement both ISelectable
        and IConduit (as, for example, tango.io.device.Device and
        tango.net.device.Socket). 

     **************************************************************************/

    private ISelectable conduit_;

    /**************************************************************************

        Instance of expiry registration struct -- used to register this client
        with a timeout / expiry registry, and to keep track of this client's
        timeout values.

     **************************************************************************/

    public ExpiryRegistration expiry_registration;

    /**************************************************************************

        Constructor
        
        Params:
            conduit_     = I/O device instance
    
     **************************************************************************/

    protected this ( ISelectable conduit_ )
    {
        this.conduit_ = conduit_;
    }
    
    /***************************************************************************

        Sets the timeout in ms.

        The timeout represents the time before which the select client should be
        completed. (This is not that same as a socket timeout, where the timout
        value represents the maximum time before which the socket should have
        seen activity.) If the client has not finished within the specified
        time, its tomeout() method is called and it is unregistered from the
        select dispatcher.

        Note: this method accepts timeout values as an int, as this is what the
        epoll_wait function (called in tango.io.selector.EpollSelector) expects.

        Params:
            ms = new timeout in ms (< 0 means timeout is disabled)

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) setTimeout ( int ms )
    {
        if ( ms >= 0 )
        {
            this.expiry_registration.setTimeout(ms * 1000);
        }
        else
        {
            this.expiry_registration.disableTimeout();
        }

        return this;
    }

    /***************************************************************************

        Disables the timeout

        Returns:
            this instance

     **************************************************************************/

    public typeof(this) disableTimeout ( )
    {
        this.setTimeout(-1);

        return this;
    }

    /**************************************************************************

        Returns the I/O device instance
        
        Returns:
             the I/O device instance
    
     **************************************************************************/
    
    final public ISelectable conduit ( )
    in
    {
        debug (ISelectClient) assert (this.conduit_ !is null, this.id ~ ": no conduit");
        else  assert (this.conduit_ !is null, typeof (this).stringof ~ ": no conduit");
    }
    body
    {
        return this.conduit_;
    }
    
    /**************************************************************************

        Sets the I/O device instance
        
        Params:
             conduit_ = I/O device instance
    
     **************************************************************************/

    final public void conduit ( ISelectable conduit_ )
    {
        this.conduit_ = conduit_;
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
             conduit = I/O device instance (as taken from Selection Key by the
                       SelectDispatcher)
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
        handle(). Intended to be overloaded by a subclass if required.
        
        Params:
            exception: Exception thrown by handle()
            event:     Seletor event while exception was caught
        
     **************************************************************************/

    public void error ( Exception exception, Event event ) { }

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

    public bool getSocketError ( out int errnum, ref char[] errmsg, char[][] msg ... )
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
    
    /**************************************************************************

        Returns an identifier string of this instance
        
        Returns:
             identifier string of this instance
    
     **************************************************************************/

    debug (ISelectClient) abstract public char[] id ( );
}

/******************************************************************************

    ISelectClientWithFinalizer abstract class
    
    Provides setting an IFinalizer instance that implements the finalize()
    method at run-time as well as an IErrorReporter implementing error().

 ******************************************************************************/

abstract class IAdvancedSelectClient : ISelectClient
{
    /**************************************************************************

        EventInfo struct
        
        Contains a Selector event and methods to test for event flags set
        
        Example:
                                                                             ---
            auto info = EventInfo(EventInfo.Event.Read | EventInfo.Event.Hangup);
            
            bool x = info.read;         // x is true
            bool y = info.write;        // y is false
            bool z = info.hangup;       // z is true
                                                                             ---
        
     **************************************************************************/

    struct EventInfo
    {
        public Event code = Event.None;
        
        /**********************************************************************
         
            Returns:
                true if the current code is clear or false if it contains an event
        
         **********************************************************************/

        public bool none ( )
        {
            return !this.code;
        }
        
        /**********************************************************************
            
            AND-Compares flags with the current code.
            
            Params:
                flags = flags to compare
                
            Returns:
                true if all bits of flags are set in the current code or false
                otherwise
        
         **********************************************************************/
        
        public bool eventFlagsSet ( Event flags )
        {
            return !!(this.code & flags);
        }
        
        /**********************************************************************
        
            Returns:
                true if all bits of flags are set in the current code or false
                otherwise
        
         **********************************************************************/

        public bool eventFlagsSetT ( Event flags ) ( )
        {
            return this.eventFlagsSet(flags);
        }
        
        public alias eventFlagsSetT!(Event.Read)          read;
        public alias eventFlagsSetT!(Event.UrgentRead)    urgent_read;
        public alias eventFlagsSetT!(Event.Write)         write;
        public alias eventFlagsSetT!(Event.Error)         error;
        public alias eventFlagsSetT!(Event.Hangup)        hangup;
        public alias eventFlagsSetT!(Event.ReadHangup)    read_hangup;
    }
    
    /**************************************************************************/

    public interface IFinalizer
    {
        void finalize ( );
    }
    
    /**************************************************************************/

    public interface IErrorReporter
    {
        void error ( Exception exception, EventInfo event );
    }

    /**************************************************************************/

    public interface IConnectionInfo
    {
        void connectionInfo ( ref char[] buffer );
    }

    /**************************************************************************/

    public interface ITimeoutReporter
    {
        void timeout ( );
    }

    /**************************************************************************

        Interface instance

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
        super (conduit);
    }

    /**************************************************************************

        Destructor

     **************************************************************************/

    ~this ( )
    {
        this.finalizer_        = null;
        this.error_reporter_   = null;
        this.connection_info_  = null;
        this.timeout_reporter_ = null;
    }

    /**************************************************************************

        Sets the TimeoutReporter. May be set to null to disable timeout
        reporting.

        Params:
            timeout_reporter_ = ITimeoutReporter instance

     **************************************************************************/

    final public void timeout_reporter ( ITimeoutReporter timeout_reporter_ )
    {
        this.timeout_reporter_ = timeout_reporter_;
    }

    /**************************************************************************

        Sets the Finalizer. May be set to null to disable finalizing.
        
        Params:
            finalizer_ = IFinalizer instance
    
     **************************************************************************/
    
    final public void finalizer ( IFinalizer finalizer_ )
    {
        this.finalizer_ = finalizer_;
    }
    
    /**************************************************************************

        Sets the Error Reporter. May be set to null to disable error reporting.
        
        Params:
            error_reporter_ = IErrorReporter instance
    
     **************************************************************************/

    final public void error_reporter ( IErrorReporter error_reporter_ )
    {
        this.error_reporter_ = error_reporter_;
    }
    
    /**************************************************************************

        Sets the Connection Info. May be set to null to disable fetching of
        connection info.
        
        Params:
            connection_info_ = IConnectionInfo instance
    
     **************************************************************************/
    
    final public void connection_info ( IConnectionInfo connection_info_ )
    {
        this.connection_info_ = connection_info_;
    }

    /**************************************************************************

        Timeout method, called after this a timeout has occurred in the
        SelectDispatcher.

     **************************************************************************/

    final override public void timeout ( )
    {
        if (this.timeout_reporter_)
        {
            this.timeout_reporter_.timeout();
        }
    }

    /**************************************************************************

        Finalize method, called after this instance has been unregistered from
        the Dispatcher.
    
     **************************************************************************/
    
    final override public void finalize ( )
    {
        if (this.finalizer_)
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

    final override public void error ( Exception exception, Event event )
    {
        if (this.error_reporter_)
        {
            this.error_reporter_.error(exception, EventInfo(event));
        }
    }
    
    /**************************************************************************

        Connection info fetching method.

        Params:
            buffer = string buffer to receive formatted connection info
        
     **************************************************************************/
    
    final override public void connectionInfo ( ref char[] buffer )
    {
        if (this.connection_info_)
        {
            this.connection_info_.connectionInfo(buffer);
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

