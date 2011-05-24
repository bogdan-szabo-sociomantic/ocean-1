module ocean.io.select.protocol.model.ISelectProtocol;



/******************************************************************************

    Imports

******************************************************************************/

private import ocean.io.select.model.ISelectClient: IAdvancedSelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.model.IConduit: ISelectable, InputStream;

private import ocean.core.Array: copy, concat;

private import TangoException = tango.core.Exception: IOException;
private import tango.net.device.Berkeley: socket_t, Berkeley;

private import tango.stdc.errno: errno, EAGAIN, EWOULDBLOCK;
private import tango.stdc.string: strlen;

debug private import tango.util.log.Trace;

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

/******************************************************************************

    ISelectProtocol abstract class

******************************************************************************/

abstract class ISelectProtocol : IAdvancedSelectClient
{
    /**************************************************************************

        Default I/O data buffer size (if a buffer is actually involved; this
        depends on the subclass implementation)
    
     **************************************************************************/
    
    const buffer_size = 0x4000;

    /**************************************************************************

        IOWarning exception instance 

     **************************************************************************/

    protected IOWarning warning_e;


    /**************************************************************************

        IOError exception instance 

     **************************************************************************/

    protected IOError error_e;


    /**************************************************************************

        Event(s) reported to handle()

     **************************************************************************/

    private Event events_reported_;

    /**************************************************************************

        Constructor

        Params:
            conduit = I/O device

     **************************************************************************/

    public this ( ISelectable conduit )
    {
        super(conduit);

        this.warning_e = new      IOWarning;
        this.error_e   = this.new IOError;
    }


    /**************************************************************************

        Handles events reported for the conduit. Invokes the abstract handle_()
        method.

        (Implements an abstract super class method.)

        Params:
            events = events which fired for conduit

        Returns:
            true to indicate to the Dispatcher that the event registration
            should be left unchanged or false to unregister the Conduit. 

     **************************************************************************/

    final bool handle ( Event events )
    {
        this.events_reported_ = events;

        return this.handle_();
    }

    /**************************************************************************

        Handles events reported for the conduit. this.events tells which events
        were reported in particular.
    
        Returns:
            true to indicate to the Dispatcher that the event registration
            should be left unchanged or false to unregister the Conduit. 
    
     **************************************************************************/

    abstract protected bool handle_ ( );
    
    /**************************************************************************

        Gets event(s) reported to handle()
    
     **************************************************************************/

    protected Event events_reported ( )
    {
        return this.events_reported_;
    }
    
    /**************************************************************************

        Performs one conduit.read(data) and checks for errors afterwards.
    
        Params:
            data = destination data buffer; data[0 .. {return value}] will
                   contain the received data 
            
        Returns:
            number of bytes read
        
        Throws:
            IOWarning on end-of-flow condition or IOError on error.
        
        Notes: Eof returned by conduit.read() together with errno reporting
            EAGAIN or EWOULDBLOCK indicates that there was currently no data to
            read but the conduit will become readable later. Thus, in that case
            0 is returned and no exception thrown.
            However, the case when conduit.read() returns Eof AND errno reports
            EAGAIN or EWOULDBLOCK AND the selector reports a hangup event for
            the conduit is treated as end-of-flow condition and an IOWarning is
            thrown then.
            The reason for this is that, as experience shows, epoll keeps
            reporting the read event together with a hangup event even if the
            conduit is actually not readable and, since it has been hung up, it
            will not become later.
            So, if conduit.read() returns EOF and errno reports EAGAIN or
            EWOULDBLOCK, the only way to detect whether a conduit will become
            readable later or not is to check if a hangup event was reported.
            
     **************************************************************************/
    
    protected size_t readConduit ( void[] data )
    in
    {
        assert ((cast (InputStream) this.conduit) !is null,
                "attempted to read from a device which is not an input stream");
    }
    body
    {
        size_t received = (cast (InputStream) this.conduit).read(data);
        
        switch ( received )
        {
            case 0:
                if ( errno ) throw this.error_e(errno, "read error", __FILE__, __LINE__);
                else         break;
            
            case InputStream.Eof: switch ( errno )
            {   
                case 0:
                    this.error_e.checkSocketError("read error", __FILE__, __LINE__);
                    throw this.warning_e("end of flow whilst reading", __FILE__, __LINE__);
                
                default:
                    throw this.error_e(errno, "read error", __FILE__, __LINE__);
                
                case EAGAIN:
                    static if ( EAGAIN != EWOULDBLOCK )
                    {
                        case EWOULDBLOCK:
                    }
    
                    this.warning_e.assertEx(!(this.events_reported_ & Event.ReadHangup), "connection hung up on read", __FILE__, __LINE__);
                    this.warning_e.assertEx(!(this.events_reported_ & Event.Hangup),     "connection hung up", __FILE__, __LINE__);
    
                    received = 0;
            }
    
            default:
        }
        
        return received;
    }
    /**************************************************************************

        IOWarning class; to be thrown on end-of-flow conditions without an
        error reported by errno or a socket error.
        
     **************************************************************************/
    
    static class IOWarning : IOException
    {
        /**********************************************************************
    
            Throws this instance if ok is false, 0 or null.
            
            Params:
                ok   = condition that must not be false, 0 or null
                msg  = message
                file = source code file name
                line = source code line
            
            Throws:
                this instance if ok is false, 0 or null
            
         **********************************************************************/
        
        void assertEx ( T ) ( T ok, char[] msg, char[] file = "", long line = 0 )
        {
            if (!ok)
            {
                super.set(msg, file, line);
                throw this;
            }
        }
        
        /**********************************************************************
    
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            super.set(msg, file, line);
            return this;
        }
        
        /**********************************************************************
    
            Sets the exception parameters.
            
            Params:
                errnum = error number
                msg    = message
                file   = source code file name
                line   = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall  ( int errnum, char[] msg, char[] file = "", long line = 0 )
        {
            super.set(errnum, msg, file, line);
            return this;
        }
    }
    
    /**************************************************************************
    
        IOError class; to be thrown on end-of-flow conditions with an error
        reported by errno or a socket error.
        
     **************************************************************************/
    
    class IOError : IOException
    {
        /**********************************************************************
    
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            super.set(msg, file, line);
            return this;
        }
        
        /**********************************************************************
    
            Sets the exception parameters.
            
            Params:
                errnum = error number
                msg    = message
                file   = source code file name
                line   = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        public typeof (this) opCall  ( int errnum, char[] msg, char[] file = "", long line = 0 )
        {
            super.set(errnum, msg, file, line);
            return this;
        }
        
        /**********************************************************************
        
            Checks the socket error state of the conduit of the outer instance.
            Does nothing if the conduit is not a socket. 
             
            Params:
                msg    = message
                file   = source code file name
                line   = source code line
            
            Throws:
                this instance if an error is reported for the conduit of the
                outer instance
            
         **********************************************************************/
        
        void checkSocketError ( char[] msg, char[] file = "", long line = 0 )
        {
            auto berkeley = Berkeley(cast (socket_t) this.outer.conduit.fileHandle);
            if (berkeley.error)
            {
                super.set(errnum, msg, file, line);
                throw this; 
            }
        }
    }
    
    /**************************************************************************
    
        IOException class; base class for IOWarning and IOError
    
     **************************************************************************/
    
    static class IOException : TangoException.IOException
    {
        /**********************************************************************
    
            This alias
        
         **********************************************************************/
        
        alias typeof (this) This;
        
        /**********************************************************************
    
            Error number
        
         **********************************************************************/
        
        int errnum = 0;
        
        /**********************************************************************
    
            Constructor
        
         **********************************************************************/
        
        this ( ) {super("");}
        
        /**********************************************************************
    
            Queries and resets errno and sets the exception parameters.
            
            Params:
                msg  = message
                file = source code file name
                line = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        protected void set ( char[] msg, char[] file = "", long line = 0 )
        {
            scope (exit) .errno = 0;
            
            this.set(.errno, msg, file, line);
        }
        
        /**********************************************************************
        
            Sets the exception parameters.
            
            Params:
                errnum = error number
                msg    = message
                file   = source code file name
                line   = source code line
            
            Returns:
                this instance
            
         **********************************************************************/
        
        protected void set ( int errnum, char[] msg, char[] file = "", long line = 0 )
        {
            this.errnum = errnum;
            
            if (this.errnum)
            {
                char[0x100] buf;
                char* e = strerror_r(errnum, buf.ptr, buf.length);
                
                super.msg.concat(msg, " - ", e[0 .. strlen(e)]);
            }
            else
            {
                super.msg.copy(msg);
            }
            
            super.file.copy(file);
            super.line = line;
        }
    }

}

