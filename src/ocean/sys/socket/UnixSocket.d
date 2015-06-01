/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Contains the Unix Socket class.

*******************************************************************************/

module ocean.sys.socket.UnixSocket;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Exception;
import ocean.sys.socket.model.ISocket;

import tango.net.device.LocalSocket;
import tango.stdc.posix.sys.socket;
import tango.stdc.posix.sys.socket;
import tango.stdc.posix.unistd;


/*******************************************************************************

    Unix Socket class.

*******************************************************************************/

public class UnixSocket : ISocket
{
    /***************************************************************************

        Constructor.

    ***************************************************************************/

    public this ()
    {
        super(LocalAddress.sockaddr_un.sizeof);
    }


    /***************************************************************************

        Creates a socket endpoint for communication and sets this.fd to the
        corresponding file descriptor.

        Params:
            type = desired socket type, which specifies the communication
                   semantics. Defaults to SOCK_STREAM.

                   For Unix Sockets the valid types are:

                     - SOCK_STREAM, for a stream-oriented socket.

                     - SOCK_DGRAM, for a datagram-oriented socket that preserves
                       message boundaries (as on most UNIX implemen‐tations,
                       UNIX domain datagram sockets are always reliable and don't
                       reorder datagrams).

                     - SOCK_SEQPACKET (since Linux 2.6.4), for a connection-oriented
                       socket that preserves message boundaries and delivers messages
                       in the order that they were sent.

        Returns:
            The socket descriptor or -1 on error.
            See the ISocket socket() implementation for details.

    ***************************************************************************/

    public int socket ( int type = SOCK_STREAM )
    {
        return super.socket(AF_UNIX, type, 0);
    }


    /***************************************************************************

        Assigns a local address to this socket.
        socket() must have been called previously.

        address = The LocalAddress instance to use. Must be non-null.

        Returns:
            0 on success or -1 on failure.
            On failure errno is set appropriately.
            See the ISocket bind() implementation for details.

    ***************************************************************************/

    public int bind ( LocalAddress address )
    in
    {
        assert(address !is null);
    }
    body
    {
        // note: cast due to duplicate but separate definitions of sockaddr
        // in Tango
        return super.bind(cast(sockaddr*)address.name());
    }


    /***************************************************************************

        Connects this socket the specified address and port.
        socket() must have been called previously.

        address = The LocalAddress instance to use. Must be non-null.

    ***************************************************************************/

    public int connect ( LocalAddress address )
    in
    {
        assert(address !is null);
    }
    body
    {
        // note: cast due to duplicate but separate definitions of sockaddr
        // in Tango
        return super.connect(cast(sockaddr*)address.name());
    }
}