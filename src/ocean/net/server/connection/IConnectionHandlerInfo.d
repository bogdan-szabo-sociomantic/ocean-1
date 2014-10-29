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

import ocean.sys.socket.model.IAddressIPSocketInfo;



public interface IConnectionHandlerInfo
{
    /***************************************************************************

        IAddressIPSocketInfo convenience alias.

    ***************************************************************************/

    alias .IAddressIPSocketInfo IAddressIPSocketInfo;


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

    IAddressIPSocketInfo socket_info ( );


    /***************************************************************************

        Formats information about the connection into the provided buffer. This
        method is called from the SelectListener in order to log information
        about the state of all connections in the pool.

        Params:
            buf = buffer to format into

    ***************************************************************************/

    void formatInfo ( ref char[] buf );
}

