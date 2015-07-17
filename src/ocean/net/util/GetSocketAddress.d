/******************************************************************************

    Memory-friendly utility to obtain the local or remote IPv4 or IPv6 socket
    address.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt

    Wraps an associative array serving as map of parameter key and value
    strings.
    The parameter keys are set on instantiation; that is, a key list is passed
    to the constructor. The keys cannot be changed, added or removed later by
    ParamSet. However, a subclass can add keys.
    All methods that accept a key handle the key case insensitively (except the
    constructor). When keys are output, the original keys are used.
    Note that keys and values are meant to slice string buffers in a subclass or
    external to this class.

 ******************************************************************************/

module ocean.net.util.GetSocketAddress;

/******************************************************************************

    Imports

 ******************************************************************************/

import tango.transition;

import tango.io.model.IConduit: ISelectable;

import tango.stdc.posix.sys.socket: getsockname, getpeername, socklen_t, sockaddr;

import tango.stdc.posix.arpa.inet: ntohs, inet_ntop, INET_ADDRSTRLEN, INET6_ADDRSTRLEN;

import tango.stdc.posix.netinet.in_: sa_family_t, in_port_t, sockaddr_in, sockaddr_in6, in_addr, in6_addr;

import tango.stdc.errno;

import consts = tango.sys.linux.consts.socket;

import tango.stdc.string: strlen;

import ocean.sys.ErrnoException;

extern (C) private char* strerror_r(int n, char* dst, size_t dst_length);

/******************************************************************************/

class GetSocketAddress
{
    /**************************************************************************

        Containt the address and accessor methods.

     **************************************************************************/

    struct Address
    {
        /**********************************************************************

            Address families: IPv4 and IPv6.

         **********************************************************************/

        enum Family : sa_family_t
        {
            INET  = consts.AF_INET,
            INET6 = consts.AF_INET6
        }

        /**********************************************************************

            Address data buffer

         **********************************************************************/

        static assert (INET6_ADDRSTRLEN >= INET_ADDRSTRLEN);

        private char[INET6_ADDRSTRLEN] addr_string_buffer;

        /**********************************************************************

            sockaddr struct instance, populated by getsockname()/getpeername().

         **********************************************************************/

        private sockaddr addr_;

        /**********************************************************************

            Reused SocketAddressException instance

         **********************************************************************/

        private SocketAddressException e;

        /**********************************************************************

            Returns:
                sockaddr struct instance as populated by getsockname()/
                getpeername().

         **********************************************************************/

        public sockaddr addr ( )
        {
            return this.addr_;
        }

        /**********************************************************************

            Returns:
                address family

         **********************************************************************/

        public Family family ( )
        {
            return cast (Family) this.addr_.sa_family;
        }

        /**********************************************************************

            Returns:
                true if the address family is supported by this struct
                (IPv4/IPv6 address) or false otherwise.

         **********************************************************************/

        public bool supported_family ( )
        {
            switch (this.family)
            {
                case Family.INET, Family.INET6:
                    return true;

                default:
                    return false;
            }
        }

        /**********************************************************************

            Returns:
                the address string.

            Throws:
                SocketAddressException if the socket address family is
                supported (other than IPv4 or IPv6).

         **********************************************************************/

        public cstring addr_string ( )
        out (a)
        {
            assert (a);
        }
        body
        {
            void* addrp = &this.addr_;

            switch (this.family)
            {
                case Family.INET:
                    addrp += sockaddr_in.init.sin_addr.offsetof;
                    break;

                case Family.INET6:
                    addrp += sockaddr_in6.init.sin6_addr.offsetof;
                    break;

                default:
                    throw this.e.set(.EAFNOSUPPORT);
            }

            char* str = .inet_ntop(this.addr_.sa_family, addrp,
                                   this.addr_string_buffer.ptr, this.addr_string_buffer.length);

            this.e.enforce(!!str, "inet_ntop");

            return str[0 .. strlen(str)];
        }

        /**********************************************************************

            Returns:
                the address port.

            Throws:
                SocketAddressException if the socket address family is
                supported (other than IPv4 or IPv6).

         **********************************************************************/

        public ushort port( )
        {
            in_port_t port;

            switch (this.family)
            {
                case Family.INET:
                    port = (cast (sockaddr_in*) &this.addr_).sin_port;
                    break;

                case Family.INET6:
                    port = (cast (sockaddr_in6*) &this.addr_).sin6_port;
                    break;

                default:
                    throw this.e.set(.EAFNOSUPPORT);
            }

            return .ntohs(port);
        }
    }

    /**************************************************************************

        Reused SocketAddressException instance. Since it is pretty unlikely to
        be thrown, it is used as a singleton and created when thrown the first
        time.

     **************************************************************************/

    private SocketAddressException e = null;

    /**************************************************************************

        Obtains the remote address associated with conduit from getpeername().
        conduit must have been downcasted from Socket.

        Params:
            conduit = socked conduit

        Returns:
            the remote address associated with conduit.

        Throws:
            SocketAddressException if getpeername() reports an error.

     **************************************************************************/

    public Address remote ( ISelectable conduit )
    {
        return this.get(conduit, &.getpeername, "getpeername");
    }

    /**************************************************************************

        Obtains the local address associated with conduit from getsockname().
        conduit must have been downcasted from Socket.

        Params:
            conduit = socked conduit

        Returns:
            the local address associated with conduit.

        Throws:
            SocketAddressException if getpeername() reports an error.

     **************************************************************************/

    public Address local ( ISelectable conduit )
    {
        return this.get(conduit, &.getsockname, "getsockname");
    }

    /**************************************************************************

        Obtains the local address associated with conduit from func().
        conduit must have been downcast from Socket.

        Params:
            conduit = socked conduit

        Returns:
            an Address instance containing the output value of func().

        Throws:
            SocketAddressException if getpeername() reports an error.

        In:
            conduit must have been downcasted from Socket.

     **************************************************************************/

    private Address get ( ISelectable conduit, typeof (&.getsockname) func, istring funcname )
    {
        Address address;

        socklen_t len = address.addr_.sizeof;

        this.e.enforce(!func(conduit.fileHandle, cast (sockaddr*) &address.addr_, &len),
                       "Cannot get local address from conduit", funcname);

        address.e = this.e;

        return address;
    }

    /**************************************************************************/

    static class SocketAddressException : ErrnoException
    {
    }
}
