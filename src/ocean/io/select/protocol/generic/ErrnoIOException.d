/******************************************************************************

    Fiber Select Protocol I/O Exception Classes

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

 ******************************************************************************/

module ocean.io.select.protocol.generic.ErrnoIOException;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.sys.ErrnoException;

import ocean.io.model.IConduit: ISelectable;

import ocean.stdc.errno: errno;

/******************************************************************************

    IOWarning class; to be thrown on end-of-flow conditions where neither errno
    nor getsockopt() indicate an error.

 ******************************************************************************/

class IOWarning : ErrnoException
{
    /**************************************************************************

        File handle of I/O device

     **************************************************************************/

    public int handle ()
    {
        return this.conduit.fileHandle;
    }

    /**************************************************************************

        Select client hosting the I/O device

     **************************************************************************/

    protected ISelectable conduit;

    /**************************************************************************

        Constructor

        Params:
            conduit =  Select client hosting the I/O device

     **************************************************************************/

    this ( ISelectable conduit )
    {
        this.conduit = conduit;
    }
}

class IOError : IOWarning
{
    /**************************************************************************

        Constructor

        Params:
            client =  Select client hosting the I/O device

     **************************************************************************/

    this ( ISelectable conduit )
    {
        super(conduit);
    }

    /**************************************************************************

        Obtains the current error code of the underlying device of the conduit.

        To be overridden by a subclass for I/O devices that support querying a
        device specific error status (e.g. sockets with getsockopt()).

        Returns:
            the current error code of the underlying device of the conduit.

     **************************************************************************/

    public int error_code ( )
    {
        return 0;
    }

    /**************************************************************************

        Checks the error state of the underlying device of the conduit and
        throws this instance on error.

        This will in fact only happen if a subclass overrides error_code().

        Params:
            msg    = message
            file   = source code file name
            line   = source code line

        Throws:
            this instance if an error is reported for the underlying device of
            the conduit.

     **************************************************************************/

    public void checkDeviceError ( istring msg, istring file = __FILE__,
                                   int line = __LINE__ )
    {
        int device_errnum = this.error_code;

        if (device_errnum)
        {
            throw this.set(device_errnum, msg, file, line);
        }
    }
}

class SocketError : IOError
{
    import ocean.sys.socket.model.ISocket;

    /**************************************************************************

        Constructor

        Params:
            conduit = I/O device, the file descriptor is expected to be
                      associated with a socket.

     **************************************************************************/

    this ( ISelectable conduit )
    {
        super(conduit);
    }

    /**************************************************************************

        Returns:
            the current socket error code.

     **************************************************************************/

    override int error_code ( )
    {
        return ISocket.error(this.conduit);
    }


    /**************************************************************************

        Throws this instance if ok is false.

        Params:
            ok   = condition that should not be false
            msg  = message
            file = source code file name
            line = source code line

        Throws:
            this instance if ok is false, 0 or null

     **************************************************************************/

    void assertExSock ( bool ok, istring msg, istring file = __FILE__,
                        int line = __LINE__ )
    {
        if (!ok) throw this.setSock(msg, file, line);
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

    public typeof (this) setSock ( lazy int errnum, istring msg,
                                   istring file = __FILE__,
                                   int line = __LINE__ )
    {
        int socket_errnum = this.error_code;

        this.set(socket_errnum? socket_errnum : errnum, msg, file, line);

        return this;
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

    public typeof (this) setSock ( istring msg, istring file = __FILE__,
                                   int line = __LINE__ )
    {
        return this.setSock(.errno, msg, file, line);
    }
}
