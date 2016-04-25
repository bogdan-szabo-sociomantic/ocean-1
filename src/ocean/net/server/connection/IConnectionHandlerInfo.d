/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-07-19: Initial release

    Authors:        Gavin Norman

    Informational (i.e. non-destructive) interface to a connection handler.

*******************************************************************************/

module ocean.net.server.connection.IConnectionHandlerInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.model.IConduit: ISelectable;


public interface IConnectionHandlerInfo
{
    // The following import must be removed when the deprecated constructors
    // will be removed.
    import ocean.sys.socket.model.IAddressIPSocketInfo;

    /***************************************************************************

        Tells whether an I/O error has been reported for the socket since the
        last assign() call.

        Returns:
            true if an I/O error has been reported for the socket or false
            otherwise.

    ***************************************************************************/

    bool io_error ( );

    /***************************************************************************

        Returns:
            informational interface to the socket used by this connection
            handler

    ***************************************************************************/

    deprecated("Please use `connected` or `fileHandle` instead. "
    "If `address` or `port` is needed, define a socket and use "
    " `socket.address` or `socket.port` instead. See release notes.")
    IAddressIPSocketInfo socket_info ( );

    /***************************************************************************

        Returns:
            true if a client connection is currently established or false if
            not.

    ***************************************************************************/

    public bool connected ( );

    /***************************************************************************

        Returns:
            I/O device instance (file descriptor under linux)

    ***************************************************************************/

    public ISelectable.Handle fileHandle ( );

    /***************************************************************************

        Formats information about the connection into the provided buffer. This
        method is called from the SelectListener in order to log information
        about the state of all connections in the pool.

        Params:
            buf = buffer to format into

    ***************************************************************************/

    void formatInfo ( ref char[] buf );
}
