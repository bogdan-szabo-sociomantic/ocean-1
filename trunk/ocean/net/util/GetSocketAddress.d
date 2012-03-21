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

private import tango.net.device.Socket;

private import tango.io.model.IConduit: ISelectable;

private import tango.stdc.posix.sys.socket: getsockname, getpeername, socklen_t, sockaddr;

private import tango.stdc.posix.arpa.inet: ntohs, inet_ntop, INET_ADDRSTRLEN, INET6_ADDRSTRLEN;

private import tango.stdc.posix.netinet.in_: sa_family_t, in_port_t, sockaddr_in, sockaddr_in6, in_addr, in6_addr;

private import tango.stdc.errno;

private import consts = tango.sys.linux.consts.socket;

private import tango.stdc.string: strlen;

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

        public char[] addr_string ( )
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
                    throw this.e.set("address family not supported", __FILE__, __LINE__);
            }
            
            char* str = .inet_ntop(this.addr_.sa_family, addrp,
                                   this.addr_string_buffer.ptr, this.addr_string_buffer.length);
            
            SocketAddressException.check(!!str, "inet_ntop", __FILE__, __LINE__, this.e);
            
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
                    throw this.e.set("address family not supported", __FILE__, __LINE__);
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
    
        Disposer
        
     **************************************************************************/

    protected override void dispose ( )
    {
        if (this.e) delete this.e;
    }
    
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

    private Address get ( ISelectable conduit, typeof (&.getsockname) func, char[] funcname )
    in
    {
        assert ((cast (Socket) conduit) !is null, "conduit is not a socket");
    }
    body
    {
        Address address;
        
        socklen_t len = address.addr_.sizeof;
        
        SocketAddressException.check(!func(conduit.fileHandle, cast (sockaddr*) &address.addr_, &len), funcname, __FILE__, __LINE__, this.e);
        
        address.e = this.e;
        
        return address;
    }
    
    /**************************************************************************/

    static class SocketAddressException : Exception
    {
        this ( ) { super(""); }
        
        /**********************************************************************
        
            If ok is false, queries errno, appends the error description to the
            error message and throws e. If e is null, it is newed.
            
            Params:
                ok   = condition to throw when false
                msg  = error message, the error description will be appended
                file = source code file name
                line = source code file line
                e    = instance of this class, set to the thrown instance if
                       null
            
            Throws:
                e if ok is false.
            
         **********************************************************************/

        static void check ( bool ok, char[] msg, char[] file, typeof (__LINE__) line,
                            ref typeof (this) e )
        {
            if (!ok)
            {
                throw (e? e : (e = new typeof (this))).setErrno(msg, file, line);
            }
        }
        
        /**********************************************************************
        
            Sets exception information.
            
            Params:
                msg  = error message, the error description will be appended
                file = source code file name
                line = source code file line
            
            Returns:
                this instance
            
         **********************************************************************/

        typeof (this) set ( char[] msg, char[] file, typeof (__LINE__) line )
        {
            this.msg.length = msg.length;
            this.msg[]      = msg;
            this.file = file;
            this.line = line;
            
            return this;
        }
        
        /**********************************************************************
        
            Sets exception information, queries errno and appends the error
            description to the error message.
            
            Params:
                msg  = error message, the error description will be appended
                file = source code file name
                line = source code file line
            
            Returns:
                this instance
            
         **********************************************************************/

        typeof (this) setErrno ( char[] msg, char[] file, typeof (__LINE__) line )
        {
            this.set(msg, file, line);
            
            int n = .errno;
            
            .errno = 0;
            
            if (n)
            {
                char[0x100] buf;
                char* e = strerror_r(n, buf.ptr, buf.length);
                
                if (super.msg.length)
                {
                    super.msg ~= " - ";
                }
                
                super.msg ~= e[0 .. strlen(e)];
            }
            
            return this;
        }
        
        
    }
}