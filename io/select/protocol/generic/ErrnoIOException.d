/******************************************************************************

    Chain/Fiber Select Protocol I/O Exception Classes
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
 ******************************************************************************/

module ocean.io.select.protocol.generic.ErrnoIOException;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import tango.core.Exception: IOException;

private import tango.stdc.errno: errno;

private import tango.stdc.string: strlen;

private import ocean.core.Array: copy, concat;

/**************************************************************************

    IOWarning class; to be thrown on end-of-flow conditions without an
    error reported by errno or a socket error.

 **************************************************************************/

class IOWarning : ErrnoIOException
{
    /**************************************************************************
    
        File handle of I/O device
        
     **************************************************************************/
    
    int handle;
    
    /**************************************************************************
    
        Select client hosting the I/O device
        
     **************************************************************************/

    private ISelectClient client;
    
    /**************************************************************************
        
        Constructor
        
        Params:
            client =  Select client hosting the I/O device
        
     **************************************************************************/

    this ( ISelectClient client )
    {
        this.client = client;
    }
    
    /**************************************************************************
    
        Throws this instance if ok is false, 0 or null.
        
        Params:
            ok   = condition that must not be false, 0 or null
            msg  = message
            file = source code file name
            line = source code line
        
        Throws:
            this instance if ok is false, 0 or null
        
     **************************************************************************/
    
    void assertEx ( T ) ( T ok, char[] msg, char[] file = "", long line = 0 )
    {
        if (!ok) throw this.opCall(msg, file, line);
    }
    
    /**************************************************************************
    
        Queries and resets errno and sets the exception parameters.
        
        Params:
            msg  = message
            file = source code file name
            line = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
    public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
    {
        super.set(msg, file, line);
        this.handle = this.client.conduit.fileHandle;
        
        return this;
    }
    
    /**************************************************************************
    
        Sets the exception parameters.
        
        Params:
            errnum = error number
            msg    = message
            file   = source code file name
            line   = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
    public typeof (this) opCall  ( int errnum, char[] msg, char[] file = "", long line = 0 )
    {
        super.set(errnum, msg, file, line);
        this.handle = this.client.conduit.fileHandle;
        
        return this;
    }
}

/******************************************************************************

    IOError class; to be thrown on end-of-flow conditions with an error
    reported by errno or a socket error.

 ******************************************************************************/

class IOError : ErrnoIOException
{
    /**************************************************************************
    
        Select client hosting the I/O device
        
     **************************************************************************/
    
    private ISelectClient client;
    
    /**************************************************************************
        
        Constructor
        
        Params:
            client =  Select client hosting the I/O device
        
     **************************************************************************/
    
    this ( ISelectClient client )
    {
        this.client = client;
    }

    /**************************************************************************
    
        Queries and resets errno and sets the exception parameters.
        
        Params:
            msg  = message
            file = source code file name
            line = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
    public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
    {
        super.set(msg, file, line);
        return this;
    }
    
    /**************************************************************************
    
        Sets the exception parameters.
        
        Params:
            errnum = error number
            msg    = message
            file   = source code file name
            line   = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
    public typeof (this) opCall  ( int errnum, char[] msg, char[] file = "", long line = 0 )
    {
        super.set(errnum, msg, file, line);
        return this;
    }
    
    /**************************************************************************
    
        Checks the socket error state of the conduit of the outer instance.
        Does nothing if the conduit is not a socket. 
         
        Params:
            msg    = message
            file   = source code file name
            line   = source code line
        
        Throws:
            this instance if an error is reported for the conduit of the
            outer instance
        
     **************************************************************************/
    
    void checkSocketError ( char[] msg, char[] file = "", long line = 0 )
    {
        if (this.client.getSocketError(super.errnum, super.msg, msg, ": "))
        {
            super.file.copy(file);
            super.line = line;
            throw this;
        }
    }
}

/******************************************************************************

    IOException class; base class for IOWarning and IOError

 ******************************************************************************/

class ErrnoIOException : IOException
{
    /**************************************************************************
    
        Error number
    
     **************************************************************************/
    
    int errnum = 0;
    
    /**************************************************************************
    
        Constructor
    
     **************************************************************************/
    
    this ( ) {super("");}
    
    /**************************************************************************
    
        Queries and resets errno and sets the exception parameters.
        
        Params:
            msg  = message
            file = source code file name
            line = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
    protected void set ( char[] msg, char[] file = "", long line = 0 )
    {
        scope (exit) .errno = 0;
        
        this.set(.errno, msg, file, line);
    }
    
    /**************************************************************************
    
        Sets the exception parameters.
        
        Params:
            errnum = error number
            msg    = message
            file   = source code file name
            line   = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
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

