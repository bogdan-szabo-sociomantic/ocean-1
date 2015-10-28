/*******************************************************************************

        copyright:      Copyright (c) 2009 Tango. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Nov 2009: Initial release

        author:         Lukas Pinkowski, Kris

*******************************************************************************/

module tango.net.device.LocalSocket;

import tango.transition;

import tango.net.device.Socket;
import tango.net.device.Berkeley;

import tango.stdc.posix.sys.un; // : sockaddr_un, UNIX_PATH_MAX;


/*******************************************************************************

        A wrapper around the Berkeley API to implement the IConduit
        abstraction and add stream-specific functionality.

*******************************************************************************/

class LocalSocket : Socket
{
        /***********************************************************************

                Create a streaming local socket

        ***********************************************************************/

        private this ()
        {
                super (AddressFamily.UNIX, SocketType.STREAM, ProtocolType.IP);
        }

        /***********************************************************************

                Create a streaming local socket

        ***********************************************************************/

        this (char[] path)
        {
                this (new LocalAddress (path));
        }

        /***********************************************************************

                Create a streaming local socket

        ***********************************************************************/

        this (LocalAddress addr)
        {
                this();
                super.connect (addr);
        }

        /***********************************************************************

                Return the name of this device

        ***********************************************************************/

        override istring toString()
        {
                return "<localsocket>";
        }
}

/*******************************************************************************


*******************************************************************************/

class LocalServerSocket : LocalSocket
{
        /***********************************************************************

        ***********************************************************************/

        this (char[] path, int backlog=32, bool reuse=false)
        {
                auto addr = new LocalAddress (path);
                native.addressReuse(reuse).bind(addr).listen(backlog);
        }

        /***********************************************************************

                Return the name of this device

        ***********************************************************************/

        override istring toString()
        {
                return "<localaccept>";
        }

        /***********************************************************************

        ***********************************************************************/

        Socket accept (Socket recipient = null)
        {
                if (recipient is null)
                    recipient = new LocalSocket;

                native.accept (*recipient.native);
                recipient.timeout = timeout;
                return recipient;
        }
}

/*******************************************************************************

*******************************************************************************/

class LocalAddress : Address
{
        alias .sockaddr_un sockaddr_un;

        protected
        {
                sockaddr_un sun;
                char[] _path;
                size_t _pathLength;
        }

        /***********************************************************************

            -path- path to a unix domain socket (which is a filename)

        ***********************************************************************/

        this (cstring path)
        {
                assert (path.length < UNIX_PATH_MAX);

                sun.sun_family = AddressFamily.UNIX;
                sun.sun_path [0 .. path.length] = path;
                sun.sun_path [path.length .. $] = 0;

                _pathLength = path.length;
                _path = sun.sun_path [0 .. path.length];
        }

        /***********************************************************************

        ***********************************************************************/

        final override sockaddr* name ()
        {
                return cast(sockaddr*) &sun;
        }

        /***********************************************************************

        ***********************************************************************/

        final override int nameLen ()
        {
                assert (_pathLength + ushort.sizeof <= int.max);
                return cast(int) (_pathLength + ushort.sizeof);
        }

        /***********************************************************************

        ***********************************************************************/

        final override AddressFamily addressFamily ()
        {
                return AddressFamily.UNIX;
        }

        /***********************************************************************

        ***********************************************************************/

        final override istring toString ()
        {
                if (isAbstract)
                {
                    auto s = "unix:abstract=" ~ _path[1..$];
                    return assumeUnique(s);
                }
                else
                {
                   auto s = "unix:path=" ~ _path;
                   return assumeUnique(s);
                }
        }

        /***********************************************************************

        ***********************************************************************/

        final char[] path ()
        {
                return _path;
        }

        /***********************************************************************

        ***********************************************************************/

        final bool isAbstract ()
        {
                return _path[0] == 0;
        }
}

/******************************************************************************

******************************************************************************/

version (UnitTest)
{
    import tango.core.Test;
    import tango.stdc.string; // : strnlen
    import tango.stdc.posix.sys.socket; // : AF_UNIX
}

unittest
{
    auto path = "I do not exist";
    auto addr = new LocalAddress(path);
    auto saddr = (cast(sockaddr_un*) addr.name);
    test!("==")(saddr.sun_family, AF_UNIX, "Family not properly set");
    test!("==")(strnlen(saddr.sun_path.ptr, UNIX_PATH_MAX), path.length,
                "Path length incorrect");
    test!("==")(saddr.sun_path.ptr[0 .. path.length], path,
                "Path not properly set");
}
