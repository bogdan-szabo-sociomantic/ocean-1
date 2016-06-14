/*******************************************************************************

    Informational (i.e. non-destructive) interface to a connection handler.

    Copyright:
        Copyright (c) 2009-2016, Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

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
