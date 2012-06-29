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

private import ocean.core.ErrnoIOException;

private import ocean.io.select.model.ISelectClient;

private import ocean.core.Array: copy;

/******************************************************************************

    IOWarning class; to be thrown on end-of-flow conditions where neither errno
    nor getsockopt() indicate an error.

 ******************************************************************************/

class IOWarning : ErrnoIOException
{
    /**************************************************************************
    
        File handle of I/O device
        
     **************************************************************************/
    
    int handle;
    
    /**************************************************************************
    
        Select client hosting the I/O device
        
     **************************************************************************/

    private const ISelectClient client;
    
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

    IOError class; to be thrown on end-of-flow conditions where either errno
    or getsockopt() indicate an error.

 ******************************************************************************/

class IOError : ErrnoIOException
{
    /**************************************************************************
    
        Select client hosting the I/O device
        
     **************************************************************************/
    
    public const ISelectClient client;
    
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
        if (this.client.getSocketErrorT(super.errnum, super.msg, msg, ": "))
        {
            super.file.copy(file);
            super.line = line;
            throw this;
        }
    }
}

