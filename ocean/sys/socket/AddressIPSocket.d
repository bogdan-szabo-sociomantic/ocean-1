/*******************************************************************************

    IP socket that memorises its address
    
    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved
    
    version:        August 2012: Initial release
    
    authors:        David Eckardt
    
    TODO: Add an AddressIPSocket subclass with host resolution.
    
*******************************************************************************/

module ocean.sys.socket.AddressIPSocket;

private import ocean.sys.socket.IPSocket,
               ocean.sys.socket.InetAddress,
               ocean.sys.socket.AddrInfo;

private import tango.io.device.Conduit: ISelectable;

private import tango.stdc.string: strlen;


/******************************************************************************

    IP socket class, memorises the address most recently passed to bind() or
    connect() or obtained by accept().
    
    Template params:
        IPv6 = true: use IPv6, false: use IPv4

 ******************************************************************************/

class AddressIPSocket ( bool IPv6 = false ) : IPSocket!(IPv6)
{
    /**************************************************************************
    
        Internet address

     **************************************************************************/
    
    alias InetAddress!(IPv6).Addr InAddr;
    
    private InetAddress!(IPv6) in_address;
    
    /**************************************************************************

        Internet address string buffer, passed to inet_pton()/inet_ntop().
    
     **************************************************************************/
    
    private char[in_address.addrstrlen] ip_address_;
    
    /**************************************************************************

        Number of valid characters in address_.
    
     **************************************************************************/
    
    private size_t ip_address_len = 0;
    
    /**************************************************************************
    
        Obtains the IP address most recently passed to bind() or connect() or
        obtained by accept().
    
        Returns:
            the current IP address.
        
     **************************************************************************/
    
    public char[] address ( )
    {
        return this.ip_address_[0 .. this.ip_address_len];
    }
    
    /**************************************************************************
    
        Obtains the port number most recently passed to bind() or connect() or
        obtained by accept().
    
        Returns:
            the current port number.
        
     **************************************************************************/
        
    public ushort port ( )
    {
        return this.in_address.port;
    }
    
    /**************************************************************************
    
        Obtains the address most recently passed to bind() or connect() or
        obtained by accept().
    
        Returns:
            the current address.
        
     **************************************************************************/
    
    public InetAddress!(IPv6).Addr in_addr ( )
    {
        return this.in_address.addr;
    }
    
    /**************************************************************************
    
        Assigns a local address and optionally a port to this socket and
        memorises address and port. This socket needs to have been created by
        socket().
        
        Params:
            local_ip_address = local IP address
            local_port       = local port or 0 to use the wildcard "any" port
            
        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.
        
        Errors:
            as above but also sets errno to EAFNOSUPPORT if the address does not
            contain a valid IP address string.
        
     **************************************************************************/

    public override int bind ( char[] local_ip_address, ushort local_port = 0 )
    {
        scope (exit) this.setAddress();
        
        return super.bind(this.in_address(local_ip_address, local_port));
    }
    
    /**************************************************************************
    
        Assigns the wildcard "any" local address and optionally a port to this
        socket and memorises address and port. This socket needs to have been
        created by socket().
        
        Params:
            local_port = local port or 0 to use the wildcard "any" port
            
        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.
        
     **************************************************************************/
    
    public override int bind ( ushort local_port )
    {
        scope (exit) this.setAddress();
        
        return super.bind(this.in_address(local_port));
    }
    
    /**************************************************************************
    
        Connects this socket the specified address and port and memorises
        address and port. This socket needs to have been created by socket().
        
        Params:
            remote_ip_address = remote IP address
            remote_port       = remote port
            
        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.
        
        Errors:
            as above but also sets errno to EAFNOSUPPORT if the address does not
            contain a valid IP address string.
        
     **************************************************************************/

    public override int connect ( char[] remote_ip_address, ushort remote_port )
    {
        scope (exit) this.setAddress();
        
        return super.connect(this.in_address(remote_ip_address, remote_port));
    }
    
    /**************************************************************************
    
        Connects this socket the specified address memorises and it. This socket
        needs to have been created by socket().
        
        Params:
            remote_address = remote address
            
        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.
        
        Errors:
            as above.
        
     **************************************************************************/
    
    public override int connect ( InAddr remote_address )
    {
        scope (exit) this.setAddress();
        
        return super.connect(this.in_address = remote_address);
    }
    
    /**************************************************************************
    
        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port. 
        
        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            flags            = socket flags, see description above
                          
        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.
        
     **************************************************************************/
    
    public override int accept ( ISelectable listening_socket,
                                 ref InAddr remote_address,
                                 SocketFlags flags = SocketFlags.None )
    {
        scope (exit) this.setAddress(remote_address);
        
        return super.accept(listening_socket, remote_address, flags);
    }
    
    /**************************************************************************
    
        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port.
        
        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            nonblocking      = true: make the accepted socket nonblocking
                               false: leave it blocking
                          
        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.
        
     **************************************************************************/
    
    public override int accept ( ISelectable listening_socket,
                                 ref InAddr remote_address, bool nonblocking )
    {
        scope (exit) this.setAddress(remote_address);
        
        return super.accept(listening_socket, remote_address, nonblocking);
    }
    
    
    /**************************************************************************
    
        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port. 
        
        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            flags            = socket flags, see description above
                          
        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.
        
     **************************************************************************/

    public override int accept ( ISelectable listening_socket,
                                 SocketFlags flags = SocketFlags.init )    
    {
        scope (exit) this.setAddress();
        
        return super.accept(listening_socket, this.in_address.addr, flags);
    }
    
    /**************************************************************************
    
        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor and memorises the remote
        address and port.
        
        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            nonblocking      = true: make the accepted socket nonblocking,
                               false: leave it blocking
                          
        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.
        
     **************************************************************************/
    
    
    public override int accept ( ISelectable listening_socket,
                                 bool nonblocking )
    {
        scope (exit) this.setAddress();
        
        return super.accept(listening_socket,
                            this.in_address.addr, nonblocking);
    }
    
    /**************************************************************************
    
        Sets this.in_address to address and updates this.ip_address_.
        
        Params:
            address = input address
        
     **************************************************************************/
    
    private void setAddress ( InAddr address )
    {
        this.in_address = address;
        this.setAddress();
    }
    
    /**************************************************************************
    
        Updates this.ip_address_.
        
     **************************************************************************/
    
    private void setAddress ( )
    {
        this.ip_address_len = this.in_address.inet_ntop(this.ip_address_).length;
    }
}
