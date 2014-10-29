/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-07-19: Initial release

    Authors:        Gavin Norman

    Informational (i.e. non-destructive) interface to an address IP socket.

*******************************************************************************/

module ocean.sys.socket.model.IAddressIPSocketInfo;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.io.device.Conduit: ISelectable;



public interface IAddressIPSocketInfo
{
    /***************************************************************************

        Returns:
            true if a client connection is currently established or false if not

    ***************************************************************************/

    bool connected ( );


    /***************************************************************************

        Returns:
            I/O device instance (file descriptor under linux)

    ***************************************************************************/

    ISelectable.Handle fileHandle ( );


    /***************************************************************************

        Obtains the IP address most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current IP address.

    ***************************************************************************/

    char[] address ( );


    /***************************************************************************

        Obtains the port number most recently passed to bind() or connect() or
        obtained by accept().

        Returns:
            the current port number.

    ***************************************************************************/

    ushort port ( );
}

