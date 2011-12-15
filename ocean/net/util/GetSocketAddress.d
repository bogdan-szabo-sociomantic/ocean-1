module ocean.net.util.GetSocketAddress;

private import tango.net.device.Socket;

private import tango.io.model.IConduit: ISelectable;

private import tango.stdc.posix.sys.socket: getsockname, getpeername, socklen_t, sockaddr;

private import tango.stdc.posix.arpa.inet: ntohs, inet_ntop, INET_ADDRSTRLEN, INET6_ADDRSTRLEN;

private import tango.stdc.posix.netinet.in_: sa_family_t, in_port_t, sockaddr_in, sockaddr_in6, in_addr, in6_addr;

private import tango.stdc.errno;

private import consts = tango.sys.linux.consts.socket;

private import tango.stdc.string: strlen;

extern (C) private char* strerror_r(int n, char* dst, size_t dst_length);

class GetSocketAddress
{
    struct Address
    {
        enum Family : sa_family_t
        {
            INET  = consts.AF_INET,
            INET6 = consts.AF_INET6
        }
        
        private static const bool[sa_family_t] supported_families;
        
        static assert (INET6_ADDRSTRLEN >= INET_ADDRSTRLEN);
        
        private char[INET6_ADDRSTRLEN] addr_string_buffer;
        
        static this ( )
        {
            this.supported_families =
            [
                Family.INET:  true,
                Family.INET6: true
            ];
            
            this.supported_families.rehash;
        }
        
        sockaddr addr;
        
        bool supported_family ( )
        {
            return !!(this.addr.sa_family in this.supported_families);
        }
        
        Family family ( )
        {
            return cast (Family) this.addr.sa_family;
        }
        
        public char[] addr_string ( )
        {
            void* addr = &this.addr;
            
            switch (this.family)
            {
                case Family.INET:
                    addr += sockaddr_in.init.sin_addr.offsetof;
                    break;
                    
                case Family.INET6:
                    addr += sockaddr_in6.init.sin6_addr.offsetof;
                    break;
                
                default:
                    return null;
            }
            
            char* str = .inet_ntop(this.addr.sa_family, addr,
                                   this.addr_string_buffer.ptr, this.addr_string_buffer.length);
            
            return str? str[0 .. strlen(str)] : null;
        }
        
        public ushort port( )
        {
            in_port_t port;
            
            switch (this.family)
            {
                case Family.INET:
                    port = (cast (sockaddr_in*) &this.addr).sin_port;
                    break;
                    
                case Family.INET6:
                    port = (cast (sockaddr_in6*) &this.addr).sin6_port;
                    break;
                
                default:
            }
            
            return .ntohs(port);
        }
    }
    
    private const SockNameException e;
    
    this ( )
    {
        this.e = new SockNameException;
    }
    
    public Address remote ( ISelectable conduit )
    {
        return this.get(conduit, &.getpeername);
    }
    
    public Address local ( ISelectable conduit )
    {
        return this.get(conduit, &.getsockname);
    }
    
    private Address get ( ISelectable conduit, typeof (&.getsockname) func )
    in
    {
        assert ((cast (Socket) conduit) !is null, "conduit is not a socket");
    }
    body
    {
        Address address;
        
        socklen_t len = address.addr.sizeof;
        
        this.e.check(!func(conduit.fileHandle, cast (sockaddr*) &address.addr, &len), "getpeername", __FILE__, __LINE__);
        
        return address;
    }
    
    static class SockNameException : Exception
    {
        this ( ) { super(""); }
        
        void check ( bool ok, char[] msg, char[] file, typeof (__LINE__) line )
        {
            if (!ok)
            {
                super.msg.length = msg.length;
                super.msg[]      = msg;
                
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
                
                super.file = file;
                super.line = line;
                
                throw this;
            }
        }
    }
}