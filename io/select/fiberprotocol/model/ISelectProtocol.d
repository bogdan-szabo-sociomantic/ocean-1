/******************************************************************************

    Fiber/coroutine based non-blocking I/O select client base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Base class for a non-blocking I/O select client using a fiber/coroutine to
    suspend operation while waiting for the I/O event and resume on that event.

 ******************************************************************************/

module ocean.io.select.fiberprotocol.model.ISelectProtocol;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import ocean.core.Array: copy, concat;

private import TangoException = tango.core.Exception: IOException;
private import tango.net.device.Berkeley: socket_t, Berkeley;

private import tango.stdc.string: strlen;
private import tango.stdc.errno: errno;

private import tango.io.Stdout;

private import tango.core.Thread : Fiber;

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

/******************************************************************************/

abstract class ISelectProtocol : IAdvancedSelectClient
{
    /**************************************************************************

        Default I/O data buffer size
    
     **************************************************************************/

    const buffer_size = 0x4000;
    
    /**************************************************************************

        Event(s) reported to handle()
    
     **************************************************************************/

    protected Event event;
    
    /**************************************************************************

        IOWarning exception instance 
    
     **************************************************************************/

    protected IOWarning warning_e;
    
    /**************************************************************************

        IOError exception instance 
    
     **************************************************************************/

    protected IOError   error_e;
    
    /**************************************************************************

        Fiber (may be shared across instances of this class)
    
     **************************************************************************/

    private Fiber fiber;
    
    /**************************************************************************

        Constructor
        
         Params:
             conduit = I/O device
             fiber   = fiber to use to suspend and resume operation
    
     **************************************************************************/

    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit);
        
        this.warning_e = new      IOWarning;
        this.error_e   = this.new IOError;
        
        this.fiber = fiber;
    }
    
    /**************************************************************************

        Resumes the fiber coroutine and handles event. The fiber must be
        suspended (HOLD state).
        
        Note that the fiber coroutine keeps going after this method has finished
        if there is another instance of this class which shares the fiber with
        this instance and is invoked in the coroutine after this instance has
        done its job.
        
        Params:
            event = I/O event
            
        Returns:
            false if the fiber is finished or true if it keeps going
    
     **************************************************************************/

    final bool handle ( Event event )
    in
    {
        assert (this.fiber.state == this.fiber.State.HOLD);
    }
    body
    {
        this.event = event;
        
        this.fiber.call();
        
        return this.fiber.state != this.fiber.State.TERM;
    }
    
    /**************************************************************************

        (Re)starts the fiber coroutine.
            
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) start ( )
    {
        if (this.fiber.state == this.fiber.State.TERM)
        {
            this.fiber.reset();
        }
        
        this.fiber.call();
        
        return this;
    }
    
    /**************************************************************************

        Suspends the fiber coroutine. The fiber must be running (EXEC state).
            
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) suspend ( )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.fiber.cede();
        
        return this;
    }
    
    /**************************************************************************

        Returns:
            current fiber state
    
     **************************************************************************/

    public Fiber.State state ( )
    {
        return this.fiber.state;
    }
    
    /**************************************************************************

        Repeatedly invokes again while again returns true; suspends the
        coroutine if again indicates continuation.
        The fiber must be running (EXEC state).
        
        Params:
            again = expression returning true to suspend and be invoked again
                    or false to quit
        
     **************************************************************************/

    protected void repeat ( lazy bool again )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        while (again())
        {
            this.suspend();
        }
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
            with (Berkeley(cast (socket_t) this.outer.conduit.fileHandle))
            {
                int errnum = error;
                
                if (errnum)
                {
                    super.set(errnum, msg, file, line);
                    throw this; 
                }
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

