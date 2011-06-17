module ocean.io.select.protocol.model.ISelectProtocol;



/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient: IAdvancedSelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.model.IConduit: ISelectable, InputStream;

private import ocean.io.select.protocol.model.ErrnoIOException;

private import ocean.core.Array: copy;

private import tango.stdc.errno: errno, EAGAIN, EWOULDBLOCK;

debug private import tango.util.log.Trace;

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

        Constructor

        Params:
            conduit = I/O device

     **************************************************************************/

    public this ( ISelectable conduit )
    {
        super(conduit);

        this.warning_e = this.new IOWarning;
        this.error_e   = this.new IOError;
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
        
        TODO: Move this method to an input specific subclass.
        
     **************************************************************************/
    
    protected size_t readConduit ( void[] data, Event events )
    in
    {
        assert ((cast (InputStream) this.conduit) !is null,
                "attempted to read from a device which is not an input stream");
    }
    body
    {
        errno = 0;
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
    
                    this.warning_e.assertEx(!(events & events.ReadHangup), "connection hung up on read", __FILE__, __LINE__);
                    this.warning_e.assertEx(!(events & events.Hangup),     "connection hung up", __FILE__, __LINE__);
    
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
    
    class IOWarning : ErrnoIOException
    {
        /**********************************************************************
        
            File handle
            
         **********************************************************************/
        
        int handle;
        
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
            if (!ok) throw this.opCall(msg, file, line);
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
            this.handle = this.outer.conduit.fileHandle;
            
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
            this.handle = this.outer.conduit.fileHandle;
            
            return this;
        }
    }
    
    /**************************************************************************
    
        IOError class; to be thrown on end-of-flow conditions with an error
        reported by errno or a socket error.
        
     **************************************************************************/
    
    class IOError : ErrnoIOException
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
            if (this.outer.getSocketError(super.errnum, super.msg, msg, ": "))
            {
                super.file.copy(file);
                super.line = line;
                throw this;
            }
        }
    }
}
