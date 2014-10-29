/******************************************************************************

    Transparent Linux IP sockets interface wrapper.

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        June 2012: Initial release

    author:         David Eckardt

 ******************************************************************************/

module ocean.sys.socket.IPSocket;

/******************************************************************************

    Imports

 ******************************************************************************/

import tango.stdc.posix.sys.socket:
           socket, bind, listen, connect, shutdown,
           recv, send,
           socklen_t, sockaddr, SOCK_STREAM, SHUT_RDWR,
           getsockopt, setsockopt, SOL_SOCKET, SO_ERROR,
           getsockname, getpeername;

import tango.stdc.posix.netinet.in_: AF_INET, AF_INET6, IPPROTO_TCP;

import tango.stdc.posix.unistd: close;

import tango.stdc.posix.sys.types: ssize_t;

import tango.io.device.Conduit: ISelectable;

import ocean.io.device.IODevice: InputDevice, IOutputDevice;

import ocean.sys.socket.InetAddress;

// FIXME: somehow the import above doesn't result in this symbol being
// identifiable in this module. Re-defining it locally.
// Perhaps this is a symptom of a circular import?
enum : uint
{
    MSG_NOSIGNAL    = 0x4000
}

/******************************************************************************

    Flags supported by .accept4() and the socket accept() methods.

 ******************************************************************************/

public enum SocketFlags
{
    None,
    SOCK_NONBLOCK = 0x800,
    SOCK_CLOEXEC  = 0x8_0000
}

/******************************************************************************

    TCP option codes supported by getsockopt()/setsockopt()
    (from <inet/netinet.h>).

 ******************************************************************************/

public enum TcpOptions
{
    None,
    TCP_NODELAY,       ///  1:  Don't delay send to coalesce packets
    TCP_MAXSEG,        ///  2:  Set maximum segment size
    TCP_CORK,          ///  3:  Control sending of partial frames
    TCP_KEEPIDLE,      ///  4:  Start keeplives after this period
    TCP_KEEPINTVL,     ///  5:  Interval between keepalives
    TCP_KEEPCNT,       ///  6:  Number of keepalives before death
    TCP_SYNCNT,        ///  7:  Number of SYN retransmits
    TCP_LINGER2,       ///  8:  Life time of orphaned FIN-WAIT-2 state
    TCP_DEFER_ACCEPT,  ///  9:  Wake up listener only when data arrive
    TCP_WINDOW_CLAMP,  /// 10:  Bound advertised window
    TCP_INFO,          /// 11:  Information about this connection.
    TCP_QUICKACK,      /// 12:  Bock/reenable quick ACKs.
    TCP_CONGESTION,    /// 13:  Congestion control algorithm.
    TCP_MD5SIG,        /// 14:  TCP MD5 Signature (RFC2385)

}

/******************************************************************************

    IP socket base class

 ******************************************************************************/

abstract class IIPSocket : InputDevice, IOutputDevice
{
    /**************************************************************************

        Flags supported by accept4().

     **************************************************************************/

    alias .SocketFlags SocketFlags;

    alias .TcpOptions TcpOptions;

    /**************************************************************************

        true for IPv6, false for IPv4.

     **************************************************************************/

    public const bool is_ipv6;

    /**************************************************************************

        File descriptor. Set by socket()/accept() and reset by close() and
        clear(). Should be modified otherwise only in special situations.

     **************************************************************************/

    public int fd = -1;

    /**************************************************************************

        If true, send() and therefore write() are requested not to send SIGPIPE
        on errors when this socket is stream oriented (e.g. TCP) and the other
        end breaks the connection.

     **************************************************************************/

    public bool suppress_sigpipe = true;

    /**************************************************************************

        If true, the destructor will call close().
        Enabled by socket()/accept() on success, disabled by close() and
        socket()/accept() on failure. Should be modified otherwise only in
        special situations.

     **************************************************************************/

    public bool close_in_destructor = false;

    /**************************************************************************

        Internet address struct (sin_addr/sin6_addr) length.

     **************************************************************************/

    public const socklen_t in_addrlen;

    /**************************************************************************

        Constructor.

        Params:
            is_ipv6    = true if this is an IPv6 socket or false if it is IPv4.
            in_addrlen = internet address struct length

     **************************************************************************/

    protected this ( bool is_ipv6, socklen_t in_addrlen )
    {
        this.is_ipv6 = is_ipv6;
        this.in_addrlen = in_addrlen;
    }

    /**************************************************************************

        Destructor. Calls close() if indicated by close_in_destructor.

     **************************************************************************/

    ~this ( )
    {
        if (this.close_in_destructor)
        {
            this.close();
        }
    }

    /**************************************************************************

        Required by ISelectable.

        Returns:
            the socket file descriptor.

     **************************************************************************/

    public Handle fileHandle ( )
    {
        return cast (Handle) this.fd;
    }

    /**************************************************************************

        Calls getsockopt(SOL_SOCKET, SO_ERROR) to obtain the current error code
        for this socket.

        Returns:
            the current error code for this socket, which can be 0, or 0 if an
            error code could not be obtained for this socket.

     **************************************************************************/

    public int error ( )
    {
        return this.error(this);
    }

    /**************************************************************************

        Calls getsockopt(SOL_SOCKET, SO_ERROR) to obtain the current error code
        for the socket referred to by fd.

        Returns:
            the current error code for this socket, which can be 0, or 0 if an
            error code could not be obtained for fd.

     **************************************************************************/

    public static int error ( ISelectable socket )
    {
        int errnum;

        socklen_t n = errnum.sizeof;

        return !.getsockopt(socket.fileHandle, SOL_SOCKET, SO_ERROR, &errnum, &n)? errnum : 0;
    }

    /**************************************************************************

        Creates an IP socket endpoint for communication and sets this.fd to the
        corresponding file descriptor.

        Params:
            type = desired socket type, which specifies the communication
                semantics.  Supported types are:

                SOCK_STREAM     Provides sequenced, reliable,  two-way,  connec‐
                                tion-based  byte  streams.   An out-of-band data
                                transmission mechanism may be supported.

                SOCK_DGRAM      Supports datagrams  (connectionless,  unreliable
                                messages of a fixed maximum length).

                SOCK_SEQPACKET  Provides  a sequenced, reliable, two-way connec‐
                                tion-based data transmission path for  datagrams
                                of  fixed maximum length; a consumer is required
                                to read an entire packet with each input  system
                                call.

                SOCK_RAW        Provides raw network protocol access.

                Some  socket  types may not be implemented by all protocol fami‐
                lies;  for  example,  SOCK_SEQPACKET  is  not  implemented   for
                AF_INET (IPv4).

                Since  Linux  2.6.27, the type argument serves a second purpose:
                in addition to specifying a socket type, it may include the bit‐
                wise  OR  of any of the following values, to modify the behavior
                of socket():

                SOCK_NONBLOCK   Set the O_NONBLOCK file status flag on  the  new
                                open  file  description.   Using this flag saves
                                extra calls to  fcntl(2)  to  achieve  the  same
                                result.

                SOCK_CLOEXEC    Set  the  close-on-exec (FD_CLOEXEC) flag on the
                                new file descriptor.  See the description of the
                                O_CLOEXEC  flag  in open(2) for reasons why this
                                may be useful.

            protocol = desired protocol or 0 to use the default protocol for the
                specified type (e.g. TCP for type = SOCK_STREAM or UDP for
                type = SOCK_DGRAM).

                The protocol specifies a particular protocol to be used with the
                socket.   Normally  only  a  single protocol exists to support a
                particular socket type within a given protocol family, in  which
                case  protocol  can  be specified as 0.  However, it is possible
                that many protocols may exist, in which case a particular proto‐
                col  must  be  specified in this manner.  The protocol number to
                use is specific to the “communication domain” in which  communi‐
                cation  is  to take place; see protocols(5).  See getprotoent(3)
                on how to map protocol name strings to protocol numbers.

                Sockets of type SOCK_STREAM are full-duplex byte streams,  simi‐
                lar to pipes.  They do not preserve record boundaries.  A stream
                socket must be in a connected state before any data may be  sent
                or  received  on  it.  A connection to another socket is created
                with a connect(2) call.  Once connected, data may be transferred
                using  read(2) and write(2) calls or some variant of the send(2)
                and recv(2) calls.  When a session has been completed a close(2)
                may  be  performed.  Out-of-band data may also be transmitted as
                described in send(2) and received as described in recv(2).


        Returns:
            the socket file descriptor on success or -1 on failure. On failure
            errno is set appropriately and this.fd is -1.

        Errors:
            EACCES Permission  to  create  a socket of the specified type and/or
                   protocol is denied.

            EAFNOSUPPORT
                   The implementation does not  support  the  specified  address
                   family.

            EINVAL Unknown protocol, or protocol family not available.

            EINVAL Invalid flags in type.

            EMFILE Process file table overflow.

            ENFILE The  system  limit on the total number of open files has been
                   reached.

            ENOBUFS or ENOMEM
                   Insufficient memory is available.  The socket cannot be  cre‐
                   ated until sufficient resources are freed.

            EPROTONOSUPPORT
                   The  protocol type or the specified protocol is not supported
                   within this domain.

            Other errors may be generated by the underlying protocol modules.

     **************************************************************************/

    public int socket ( int type, int protocol = 0 )
    {
        this.fd = .socket(this.is_ipv6? AF_INET6 : AF_INET, type, protocol);

        this.close_in_destructor = (this.fd >= 0);

        return this.fd;
    }

    /**************************************************************************

        Calls socket() to create a TCP/IP socket, setting this.fd to the file
        descriptor.

        Params:
            nonblocking = true: make the socket nonblocking, false: make it
                          blocking

        Returns:
            the socket file descriptor on success or -1 on failure. On failure
            errno is set appropriately and this.fd is -1.

     **************************************************************************/

    public int tcpSocket ( bool nonblocking = false )
    {
        const int[2] type = [SOCK_STREAM,
                             SOCK_STREAM | SocketFlags.SOCK_NONBLOCK];

        return this.socket(type[nonblocking], IPPROTO_TCP);
    }

    /**************************************************************************

        Assigns a local address to this socket. This socket needs to have been
        created by socket().

        Note: This generic wrapper should be used only in special situations,
        the subclass variants for a particular address family are preferred.

        Params:
            address = local internet address, expected to point to a sin_addr
                      or sin6_addr instance, depending on the IP version of this
                      instance

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            EACCES The address is protected, and the user is not the superuser.

            EADDRINUSE
                   The given address is already in use.

            EBADF  sockfd is not a valid descriptor.

            EINVAL The socket is already bound to an address.

            ENOTSOCK
                   The file descriptor is a descriptor for a file, not a socket.

     **************************************************************************/

    public int bind ( sockaddr* local_address )
    {
        return .bind(this.fd, local_address, this.in_addrlen);
    }

    /**************************************************************************

        Accepts a connection from a listening socket and sets this.fd to the
        accepted socket file descriptor.

        Note: This generic wrapper should be used only in special situations,
        the subclass variants for a particular address family are preferred.

        The  accept()  system  call  is  used with connection-based socket types
        (SOCK_STREAM, SOCK_SEQPACKET).  It extracts the first connection request
        on  the  queue  of pending connections for the listening socket, creates
        a new connected socket, and returns a new file descriptor  referring  to
        that socket.  The newly  created socket  is not in the listening  state.
        The original socket is unaffected by this call.

        If  no  pending  connections are present on the queue, and the socket is
        not marked as nonblocking, accept() blocks the caller until a connection
        is  present.  If the socket is marked nonblocking and no pending connec‐
        tions are present on the queue, accept() fails with the error EAGAIN  or
        EWOULDBLOCK.

        In order to be notified of incoming connections on a socket, you can use
        select(2) or poll(2).  A readable event will be  delivered  when  a  new
        connection  is  attempted and you may then call accept() to get a socket
        for that connection.  Alternatively, you can set the socket  to  deliver
        SIGIO when activity occurs on a socket; see socket(7) for details.

        Params:
            listening_fd   = the file descriptor of the listening socket to
                             accept the new connection from
            remote_address = filled in with the address of the peer socket, as
                             known to the communications layer; expected to
                             point to a sin_addr or sin6_addr instance,
                             depending on the IP version of this instance
            addrlen        = actual address struct length output, initialised to
                             this.in_addrlen; returning a different value
                             indicates socket family mixup

            flags =
                The following  values  can be bitwise ORed in flags:

                SOCK_NONBLOCK   Set the O_NONBLOCK file status flag on  the  new
                                open  file  description.   Using this flag saves
                                extra calls to  fcntl(2)  to  achieve  the  same
                                result.

                SOCK_CLOEXEC    Set  the  close-on-exec (FD_CLOEXEC) flag on the
                                new file descriptor.  See the description of the
                                O_CLOEXEC  flag  in open(2) for reasons why this
                                may be useful.

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

        Errors:
            EAGAIN or EWOULDBLOCK
                   The  socket  is  marked  nonblocking  and  no connections are
                   present to be accepted.

            EBADF  The descriptor is invalid.

            ECONNABORTED
                   A connection has been aborted.

            EFAULT The  addr  argument  is  not  in  a writable part of the user
                   address space.

            EINTR  The system call was interrupted by a signal that  was  caught
                   before a valid connection arrived; see signal(7).

            EINVAL Socket  is  not  listening  for  connections,  or  addrlen is
                   invalid (e.g., is negative).

            EINVAL invalid value in flags.

            EMFILE The per-process limit  of  open  file  descriptors  has  been
                   reached.

            ENFILE The  system  limit on the total number of open files has been
                   reached.

            ENOBUFS, ENOMEM
                   Not enough free memory.  This often  means  that  the  memory
                   allocation is limited by the socket buffer limits, not by the
                   system memory.

            ENOTSOCK
                   The descriptor references a file, not a socket.

            EOPNOTSUPP
                   The referenced socket is not of type SOCK_STREAM.

            EPROTO Protocol error.

            In addition, Linux accept() may fail if:

            EPERM  Firewall rules forbid connection.

            In addition, network errors for the new socket and  as  defined  for
            the  protocol  may  be  returned.   Various Linux kernels can return
            other  errors  such  as  ENOSR,  ESOCKTNOSUPPORT,   EPROTONOSUPPORT,
            ETIMEDOUT.  The value ERESTARTSYS may be seen during a trace.

     **************************************************************************/

    public int accept ( ISelectable listening_socket,
                        sockaddr* remote_address, out socklen_t addrlen,
                        SocketFlags flags = SocketFlags.None )
    {
        addrlen = this.in_addrlen;

        this.fd = .accept4(listening_socket.fileHandle, remote_address, &addrlen, flags);

        this.close_in_destructor = (this.fd >= 0);

        return this.fd;
    }

    /**************************************************************************

        Accepts a connection from a listening socket and sets this.fd to the
        accepted socket file descriptor.

        See description above for further information.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            flags            = socket flags, see description above

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public int accept ( ISelectable listening_socket, SocketFlags flags = SocketFlags.None )
    {
        this.fd = .accept4(listening_socket.fileHandle, null, null, flags);

        this.close_in_destructor = (this.fd >= 0);

        return this.fd;
    }

    /**************************************************************************

        Accepts a connection from a listening socket and sets this.fd to the
        accepted socket file descriptor.

        See description above for further information.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            nonblocking      = true: make the accepted socket nonblocking,
                               false: leave it blocking

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public int accept ( ISelectable listening_socket, bool nonblocking )
    {
        const SocketFlags[2] flags = [SocketFlags.None, SocketFlags.SOCK_NONBLOCK];

        return this.accept(listening_socket, flags[nonblocking]);
    }

    /**************************************************************************

        Connects this socket the specified address and port.

        Note: This generic wrapper should be used only in special situations,
        the subclass variants for a particular address family are preferred.

        If  this socket is of type SOCK_DGRAM  then the  address  is the one  to
        which datagrams are sent by default, and the  only  address  from  which
        datagrams  are  received.   If  the  socket  is  of  type SOCK_STREAM or
        SOCK_SEQPACKET, this call attempts to make a connection  to  the  socket
        that is bound to the address specified by addr.

        Generally,  connection-based protocol sockets may successfully connect()
        only once; connectionless protocol sockets may  use  connect()  multiple
        times  to change their association.  Connectionless sockets may dissolve
        the association by connecting to an address with the sa_family member of
        sockaddr set to AF_UNSPEC (supported on Linux since kernel 2.2).

        Params:
            address = remote internet address, expected to point to a sin_addr
                      or sin6_addr instance, depending on the IP version of this
                      instance

        Returns:
            0 on success or -1 on failure. On error failure is set
            appropriately.

        Errors:
            The  following  are  general socket errors only.  There may be other
            domain-specific error codes.

            EACCES For Unix domain sockets, which are  identified  by  pathname:
                   Write permission is denied on the socket file, or search per‐
                   mission is denied for one of the directories in the path pre‐
                   fix.  (See also path_resolution(7).)

            EACCES, EPERM
                   The user tried to connect to a broadcast address without hav‐
                   ing the socket  broadcast  flag  enabled  or  the  connection
                   request failed because of a local firewall rule.

            EADDRINUSE
                   Local address is already in use.

            EAFNOSUPPORT
                  The passed address didn't have the correct address family in
                  its sa_family field.

            EAGAIN No more free local ports or insufficient entries in the rout‐
                   ing    cache.    For   AF_INET   see   the   description   of
                   /proc/sys/net/ipv4/ip_local_port_range ip(7) for  information
                   on how to increase the number of local ports.

            EALREADY
                   The  socket  is nonblocking and a previous connection attempt
                   has not yet been completed.

            EBADF  The file descriptor is not a valid index  in  the  descriptor
                   table.

            ECONNREFUSED
                   No-one listening on the remote address.

            EFAULT The  socket  structure  address is outside the user's address
                   space.

            EINPROGRESS
                   The socket is nonblocking and the connection cannot  be  com‐
                   pleted  immediately.   It is possible to select(2) or poll(2)
                   for completion by selecting the socket  for  writing.   After
                   select(2)  indicates  writability,  use getsockopt(2) to read
                   the SO_ERROR option at level SOL_SOCKET to determine  whether
                   connect() completed successfully (SO_ERROR is zero) or unsuc‐
                   cessfully (SO_ERROR is one of the usual  error  codes  listed
                   here, explaining the reason for the failure).

            EINTR  The  system call was interrupted by a signal that was caught;
                   see signal(7).

            EISCONN
                   The socket is already connected.

            ENETUNREACH
                   Network is unreachable.

            ENOTSOCK
                   The file descriptor is not associated with a socket.

            ETIMEDOUT
                   Timeout while attempting connection.  The server may  be  too
                   busy to accept new connections.  Note that for IP sockets the
                   timeout may be very long when syncookies are enabled  on  the
                   server.

     **************************************************************************/

    public int connect ( sockaddr* remote_address )
    {
        return .connect(this.fd, remote_address, this.in_addrlen);
    }

    /**************************************************************************

        listen() marks this socket as a passive socket, that is, as a socket
        that will be used to accept incoming connection requests using
        accept().

        Params:
            backlog =
                The backlog argument defines the maximum  length  to  which  the
                queue  of pending connections for sockfd may grow.  If a connec‐
                tion request arrives when the queue  is  full,  the  client  may
                receive  an  error with an indication of ECONNREFUSED or, if the
                underlying protocol supports retransmission, the request may  be
                ignored so that a later reattempt at connection succeeds.

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            EADDRINUSE
                   Another socket is already listening on the same port.

            EBADF  The argument sockfd is not a valid descriptor.

            ENOTSOCK
                   The argument sockfd is not a socket.

            EOPNOTSUPP
                   The socket is not of a type that  supports  the  listen()
                   operation.


     **************************************************************************/

    public int listen ( int backlog )
    {
        return .listen(this.fd, backlog);
    }

    /**************************************************************************

        The shutdown() call causes all or part of a full-duplex connection on
        the socket to be shut down.

        Params:
            how =
                - SHUT_RD: further receptions will be disallowed,
                - SHUT_WR: further transmissions will be disallowed,
                - SHUT_RDWR: further receptions and transmissions will be disal‐
                  lowed.
        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            EBADF  The argument sockfd is not a valid descriptor.

            ENOTSOCK
                   The argument sockfd is not a socket.

            ENOTCONN
                   The specified socket is not connected.

     **************************************************************************/

    public int shutdown ( int how = SHUT_RDWR )
    {
        return .shutdown(this.fd, how);
    }

    /**************************************************************************

        Obtains the value of a socket option, writing the value data to dst.

        Note: The actual value data type and length depends on the particular
        option. If the returned value is above dst.length, dst contains the
        first bytes of the truncated value. If the returned value is below
        dst.length on success, it indicates the number of bytes in dst written
        to.

        Params:
            level   = socket option level
            optname = socket option name
            dst     = value destination buffer

        Returns:
            the actual value length on success or -1 on failure.
            On failure errno is set appropriately.

        Errors:
            EBADF  The argument sockfd is not a valid descriptor.

            EFAULT dst is not in a valid part of the process address space.

            ENOPROTOOPT
                   The option is unknown at the level indicated.

            ENOTSOCK
                   The argument sockfd is a file, not a socket.

     **************************************************************************/

    public ssize_t getsockopt ( int level, int optname, void[] dst )
    {
        socklen_t result_len = dst.length;

        int r = .getsockopt(this.fd, level, optname, dst.ptr, &result_len);

        return r? r : result_len;
    }

    /**************************************************************************

        Calls getsockopt() to obtain the value of a socket option.

        Notes:
            - The actual value data type T depends on the particular option. If
              the returned value differs from val.sizeof on success, the wrong
              type was used and val contains most likely junk.
            - T = bool is internally substituted by int and therefore suitable
              for flag options.

        Params:
            level   = socket option level
            optname = socket option name
            val     = value output

        Returns:
            the actual value length on success or -1 on failure.
            On failure errno is set appropriately.

     **************************************************************************/

    public ssize_t getsockoptVal ( T ) ( int level, int optname, out T val )
    {
        static if (is (T == bool))
        {
            int dst;

            scope (success) val = !!dst;
        }
        else
        {
            alias val dst;
        }

        return this.getsockopt(level, optname, (cast (void*) &dst)[0 .. dst.sizeof]);
    }

    /**************************************************************************

        Sets the value of a socket option, using the value data in src.
        The actual value data type and length depends on the particular option.

        Params:
            level   = socket option level
            optname = socket option name
            src     = value source buffer

        Returns:
            0 on success or -1 on failure.
            On failure errno is set appropriately.

        Errors:
            EBADF - The argument sockfd is not a valid descriptor.

            EFAULT - src is not in a valid part of the process address space.

            EINVAL - src.length does not match the expected value length.

            ENOPROTOOPT - The option is unknown at the level indicated.

            ENOTSOCK - The argument sockfd is a file, not a socket.

     **************************************************************************/

    public int setsockopt ( int level, int optname, void[] src )
    {
        return .setsockopt(this.fd, level, optname, src.ptr, src.length);
    }

    /**************************************************************************

        Calls setsockopt() to sets the value of a socket option to val.

        Notes:
            - The actual value data type T depends on the particular option.
              Failure with EINVAL indicates that a type of the wrong size was
              used.
            - T = bool is internally substituted by int and therefore suitable
              for flag options.

        Params:
            level   = socket option level
            optname = socket option name
            val     = option value

        Returns:
            0 on success or -1 on failure.
            On failure errno is set appropriately.

     **************************************************************************/

    public int setsockoptVal ( T ) ( int level, int optname, T val )
    {
        static if (is (T == bool))
        {
            int src = val;
        }
        else
        {
            alias val src;
        }

        return this.setsockopt(level, optname, (cast (void*) &src)[0 .. src.sizeof]);
    }

    /**************************************************************************

        Calls send() to send as many src bytes as possible.

        Note: May raise ESIGPIPE on errors when this socket is stream oriented
        (e.g. TCP), the other end breaks the connection and
        this.suppress_sigpipe is false.

        Params:
            src = data to send

        Returns:
            the number of src bytes sent on success or -1 on failure.
            On failure errno is set appropriately.

     **************************************************************************/

    public ssize_t write ( void[] src )
    {
        return this.send(src, 0);
    }

    /**************************************************************************

        Sends as many src bytes as possible to the remote.

        Note: May raise ESIGPIPE on errors when this socket is stream oriented
        (e.g. TCP), the other end breaks the connection flags does not contain
        MSG_NOSIGNAL. If  this.suppress_sigpipe is true, MSG_NOSIGNAL will be
        set in flags automatically.

        Params:
            src   = data to send
            flags =  the bitwise OR of zero or more of the following flags:

                MSG_CONFIRM (Since Linux 2.3.15)
                       Tell  the  link layer that forward progress happened: you
                       got a successful reply from the other side.  If the  link
                       layer  doesn't  get  this  it  will regularly reprobe the
                       neighbor (e.g.,  via  a  unicast  ARP).   Only  valid  on
                       SOCK_DGRAM and SOCK_RAW sockets and currently only imple‐
                       mented for IPv4 and IPv6.  See arp(7) for details.

                MSG_DONTROUTE
                       Don't use a gateway to send out the packet, only send  to
                       hosts  on  directly  connected networks.  This is usually
                       used only by diagnostic or  routing  programs.   This  is
                       only  defined  for  protocol  families that route; packet
                       sockets don't.

                MSG_DONTWAIT (since Linux 2.2)
                       Enables nonblocking operation;  if  the  operation  would
                       block,  EAGAIN  or EWOULDBLOCK is returned (this can also
                       be enabled using the O_NONBLOCK  flag  with  the  F_SETFL
                       fcntl(2)).

                MSG_EOR (since Linux 2.2)
                       Terminates  a  record  (when this notion is supported, as
                       for sockets of type SOCK_SEQPACKET).

                MSG_MORE (Since Linux 2.4.4)
                       The caller has more data to send.  This flag is used with
                       TCP  sockets  to  obtain  the same effect as the TCP_CORK
                       socket option (see tcp(7)), with the difference that this
                       flag can be set on a per-call basis.

                       Since  Linux  2.6,  this  flag  is also supported for UDP
                       sockets, and informs the kernel to  package  all  of  the
                       data sent in calls with this flag set into a single data‐
                       gram which is only transmitted when a call  is  performed
                       that  does not specify this flag.  (See also the UDP_CORK
                       socket option described in udp(7).)

                MSG_NOSIGNAL (since Linux 2.2)
                       Requests not to send SIGPIPE on errors on stream oriented
                       sockets  when  the  other end breaks the connection.  The
                       EPIPE error is still returned.

                MSG_OOB
                       Sends out-of-band  data  on  sockets  that  support  this
                       notion (e.g., of type SOCK_STREAM); the underlying proto‐
                       col must also support out-of-band data.

        Returns:
            the number of src bytes sent on success or -1 on failure.
            On failure errno is set appropriately.

        Errors:
            These are some standard errors generated by the socket layer.  Addi‐
            tional errors may be generated and returned from the underlying pro‐
            tocol modules; see their respective manual pages.

            EACCES (For Unix domain sockets, which are identified  by  pathname)
                   Write permission is denied on the destination socket file, or
                   search permission is denied for one of  the  directories  the
                   path prefix.  (See path_resolution(7).)

            EAGAIN or EWOULDBLOCK
                   The  socket is marked nonblocking and the requested operation
                   would block.  POSIX.1-2001 allows either error to be returned
                   for  this  case, and does not require these constants to have
                   the same value, so a portable application  should  check  for
                   both possibilities.

            EBADF  An invalid descriptor was specified.

            ECONNRESET
                   Connection reset by peer.

            EDESTADDRREQ
                   The  socket  is  not  connection-mode, and no peer address is
                   set.

            EFAULT An invalid user space address was specified for an argument.

            EINTR  A signal occurred before any data was transmitted;  see  sig‐
                   nal(7).

            EINVAL Invalid argument passed.

            EISCONN
                   The connection-mode socket was connected already but a recip‐
                   ient was specified.  (Now either this error is  returned,  or
                   the recipient specification is ignored.)

            EMSGSIZE
                   The socket type requires that message be sent atomically, and
                   the size of the message to be sent made this impossible.

            ENOBUFS
                   The output queue for a network interface was full.  This gen‐
                   erally  indicates that the interface has stopped sending, but
                   may be caused by transient congestion.  (Normally, this  does
                   not occur in Linux.  Packets are just silently dropped when a
                   device queue overflows.)

            ENOMEM No memory available.

            ENOTCONN
                   The socket is not connected, and no target has been given.

            ENOTSOCK
                   The argument sockfd is not a socket.

            EOPNOTSUPP
                   Some bit in the  flags  argument  is  inappropriate  for  the
                   socket type.

            EPIPE  The  local  end  has  been shut down on a connection oriented
                   socket.  In this case the process will also receive a SIGPIPE
                   unless MSG_NOSIGNAL is set.

     **************************************************************************/

    public ssize_t send ( void[] src, int flags )
    {
        return .send(this.fd, src.ptr, src.length,
                     this.suppress_sigpipe? flags | MSG_NOSIGNAL : flags);
    }

    /**************************************************************************

        Receives dst.length bytes from the remote but at most as possible with
        one attempt.


        Params:
            src   = data to send
            flags =  the bitwise OR of zero or more of the following flags:

                MSG_CMSG_CLOEXEC (recvmsg() only; since Linux 2.6.23)
                       Set  the  close-on-exec  flag  for  the  file  descriptor
                       received via a Unix  domain  file  descriptor  using  the
                       SCM_RIGHTS  operation  (described in unix(7)).  This flag
                       is useful for the same reasons as the O_CLOEXEC  flag  of
                       open(2).

                MSG_DONTWAIT (since Linux 2.2)
                       Enables  nonblocking  operation;  if  the operation would
                       block, the call fails with the error  EAGAIN  or  EWOULD‐
                       BLOCK (this can also be enabled using the O_NONBLOCK flag
                       with the F_SETFL fcntl(2)).
                MSG_OOB
                       This flag requests receipt of out-of-band data that would
                       not be received in the normal data stream.   Some  proto‐
                       cols  place expedited data at the head of the normal data
                       queue, and thus this flag cannot be used with such proto‐
                       cols.

                MSG_PEEK
                       This  flag  causes  the  receive operation to return data
                       from the beginning of the receive queue without  removing
                       that  data  from  the  queue.  Thus, a subsequent receive
                       call will return the same data.

                MSG_TRUNC (since Linux 2.2)
                       For  raw  (AF_PACKET),  Internet  datagram  (since  Linux
                       2.4.27/2.6.8),  and netlink (since Linux 2.6.22) sockets:
                       return the real length of the packet  or  datagram,  even
                       when  it  was  longer than the passed buffer.  Not imple‐
                       mented for Unix domain (unix(7)) sockets.

                       For use with Internet stream sockets, see tcp(7).

                MSG_WAITALL (since Linux 2.2)
                       This flag requests that the  operation  block  until  the
                       full  request  is satisfied.  However, the call may still
                       return less data than requested if a signal is caught, an
                       error  or  disconnect  occurs,  or  the  next  data to be
                       received is of a different type than that returned.
                MSG_EOR
                       indicates  end-of-record;  the  data returned completed a
                       record (generally used with  sockets  of  type  SOCK_SEQ‐
                       PACKET).

                MSG_TRUNC
                       indicates  that  the  trailing  portion of a datagram was
                       discarded because the datagram was larger than the buffer
                       supplied.

                MSG_CTRUNC
                       indicates  that  some  control data were discarded due to
                       lack of space in the buffer for ancillary data.

                MSG_OOB
                       is returned to indicate  that  expedited  or  out-of-band
                       data were received.

                MSG_ERRQUEUE
                       indicates that no data was received but an extended error
                       from the socket error queue.

        Returns:
            the number of bytes received on success or -1 on failure.
            On failure errno is set appropriately.

        Errors:

            EAGAIN or EWOULDBLOCK
                   The socket is marked nonblocking and  the  receive  operation
                   would  block, or a receive timeout had been set and the time‐
                   out expired before data was  received.   POSIX.1-2001  allows
                   either  error  to  be  returned  for  this case, and does not
                   require these constants to have the same value, so a portable
                   application should check for both possibilities.

            EBADF  The argument sockfd is an invalid descriptor.

            ECONNREFUSED
                   A  remote host refused to allow the network connection (typi‐
                   cally because it is not running the requested service).

            EFAULT The receive buffer pointer(s)  point  outside  the  process's
                   address space.

            EINTR  The  receive  was  interrupted by delivery of a signal before
                   any data were available; see signal(7).

            EINVAL Invalid argument passed.

            ENOMEM Could not allocate memory for recvmsg().

            ENOTCONN
                   The socket is associated with a connection-oriented  protocol
                   and has not been connected (see connect(2) and accept(2)).

            ENOTSOCK
                   The argument sockfd does not refer to a socket.

     **************************************************************************/

    public ssize_t recv ( void[] dst, int flags )
    {
        return .recv(this.fd, dst.ptr, dst.length, flags);
    }

    /**************************************************************************

        Obtains the local socket address.

        Note: This generic wrapper should be used only in special situations,
        the subclass variants for a particular address family are preferred.

        getsockname() returns the current address to which this socket is bound,
        in the buffer pointed to by local_address. The addrlen argument is
        initialized to this.in_addrlen which indicates the amount of space
        pointed to by addr. On return it contains the actual size of the name
        returned (in bytes). The name is truncated if the buffer provided is
        too small; in this case, addrlen will return a value greater than
        this.in_addrlen.

        Params:
            local_address = filled in with the address of the local socket, as
                             known to the communications layer; expected to
                             point to a sin_addr or sin6_addr instance,
                             depending on the IP version of this instance
            addrlen        = actual address struct length output, initialised to
                             this.in_addrlen; returning a different value
                             indicates socket family mixup

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF this.fd is not a valid descriptor.

            EFAULT local_address points to memory not in a valid part of the
                process address space.

            EINVAL addrlen is invalid (e.g., is negative).

            ENOBUFS
                Insufficient resources were available in the system to perform
                the operation.

            ENOTSOCK
                this.fd is a file, not a socket.

     **************************************************************************/

    public int getsockname ( sockaddr* local_address, out socklen_t addrlen )
    {
        addrlen = this.in_addrlen;

        return .getsockname(this.fd, local_address, &addrlen);
    }

    /**************************************************************************

        Obtains the remote socket address.

        Note: This generic wrapper should be used only in special situations,
        the subclass variants for a particular address family are preferred.

        getpeername() returns the address of the peer connected to this socket,
        in the buffer pointed to by remote_address. The addrlen argument is
        initialized to this.in_addrlen which indicates the amount of space
        pointed to by addr. On return it contains the actual size of the name
        returned (in bytes). The name is truncated if the buffer provided is
        too small; in this case, addrlen will return a value greater than
        this.in_addrlen.

        Params:
            remote_address = filled in with the address of the remote socket, as
                             known to the communications layer; expected to
                             point to a sin_addr or sin6_addr instance,
                             depending on the IP version of this instance
            addrlen        = actual address struct length output, initialised to
                             this.in_addrlen; returning a different value
                             indicates socket family mixup

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF this.fd is not a valid descriptor.

            EFAULT remote_address points to memory not in a valid part of the
                process address space.

            EINVAL addrlen is invalid (e.g., is negative).

            ENOBUFS
                Insufficient resources were available in the system to perform
                the operation.

            ENOTCONN
                The socket is not connected.

            ENOTSOCK
                this.fd is a file, not a socket.

     **************************************************************************/

    public int getpeername ( sockaddr* remote_address, out socklen_t addrlen )
    {
        addrlen = this.in_addrlen;

        return .getpeername(this.fd, remote_address, &addrlen);
    }

    /**************************************************************************

        Closes the socket and resets the file descriptor, address and port.

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF  fd isn't a valid open file descriptor.

            EINTR  The close() call was interrupted by a signal; see signal(7).

            EIO    An I/O error occurred.

     **************************************************************************/

    public int close ( )
    {
        scope (success) this.clear();

        return .close(this.fd);
    }

    /**************************************************************************

        Resets the file descriptor, address and port.
        Called from close(), should be called otherwise only in special
        situations.

     **************************************************************************/

    public void clear ( )
    {
        this.fd                  = -1;
        this.close_in_destructor = false;
    }
}

/******************************************************************************

    IP socket class, contains the IPv4/6 address specific parts.

    Template params:
        IPv6 = true: use IPv6, false: use IPv4

 ******************************************************************************/

class IPSocket ( bool IPv6 = false ) : IIPSocket
{
    alias .InetAddress!(IPv6) InetAddress;

    /**************************************************************************

        Type alias of the "sin" internet address struct type, sockaddr_in for
        IPv4 or sockaddr_in6 for IPv6.

     **************************************************************************/

    alias InetAddress.Addr InAddr;

    /**************************************************************************

        Constructor.

     **************************************************************************/

    public this ( )
    {
        super(IPv6, InAddr.sizeof);
    }

    /**************************************************************************

        Assigns a local address to this socket. This socket needs to have been
        created by socket().

        Params:
            local_address = local address

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

        Errors:
            EACCES The address is protected, and the user is not the superuser.

            EADDRINUSE
                   The given address is already in use.

            EBADF  sockfd is not a valid descriptor.

            EINVAL The socket is already bound to an address.

            ENOTSOCK
                   The file descriptor is a descriptor for a file, not a socket.

     **************************************************************************/

    public int bind ( InAddr local_address )
    {
        return super.bind(cast (sockaddr*) &local_address);
    }

    /**************************************************************************

        Assigns a local address and optionally a port to this socket.
        This socket needs to have been created by socket().

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

    public int bind ( char[] local_ip_address, ushort local_port = 0 )
    {
        InetAddress!(IPv6) in_address;

        sockaddr* local_address = in_address(local_ip_address, local_port);

        return local_address? super.bind(local_address) : -1;
    }

    /**************************************************************************

        Assigns the wildcard "any" local address and optionally a port to this
        socket. This socket needs to have been created by socket().

        Params:
            local_port = local port or 0 to use the wildcard "any" port

        Returns:
            0 on success or -1 on failure. On failure errno is set
            appropriately.

     **************************************************************************/

    public int bind ( ushort local_port = 0 )
    {
        InetAddress!(IPv6) in_address;

        return super.bind(in_address(local_port));
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int bind ( sockaddr* local_address )
    {
        return super.bind(local_address);
    }

    /**************************************************************************

        Accepts a connection from a listening socket and sets this.fd to the
        accepted socket file descriptor.

        The  accept()  system  call  is  used with connection-based socket types
        (SOCK_STREAM, SOCK_SEQPACKET).  It extracts the first connection request
        on  the  queue  of pending connections for the listening socket, creates
        a new connected socket, and returns a new file descriptor  referring  to
        that socket.  The newly  created socket  is not in the listening  state.
        The original socket is unaffected by this call.

        If  no  pending  connections are present on the queue, and the socket is
        not marked as nonblocking, accept() blocks the caller until a connection
        is  present.  If the socket is marked nonblocking and no pending connec‐
        tions are present on the queue, accept() fails with the error EAGAIN  or
        EWOULDBLOCK.

        In order to be notified of incoming connections on a socket, you can use
        select(2) or poll(2).  A readable event will be  delivered  when  a  new
        connection  is  attempted and you may then call accept() to get a socket
        for that connection.  Alternatively, you can set the socket  to  deliver
        SIGIO when activity occurs on a socket; see socket(7) for details.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            flags =
                The following  values  can be bitwise ORed in flags:

                SOCK_NONBLOCK   Set the O_NONBLOCK file status flag on  the  new
                                open  file  description.   Using this flag saves
                                extra calls to  fcntl(2)  to  achieve  the  same
                                result.

                SOCK_CLOEXEC    Set  the  close-on-exec (FD_CLOEXEC) flag on the
                                new file descriptor.  See the description of the
                                O_CLOEXEC  flag  in open(2) for reasons why this
                                may be useful.



        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

        Errors:
            EAGAIN or EWOULDBLOCK
                   The  socket  is  marked  nonblocking  and  no connections are
                   present to be accepted.

            EBADF  The descriptor is invalid.

            ECONNABORTED
                   A connection has been aborted.

            EFAULT The  addr  argument  is  not  in  a writable part of the user
                   address space.

            EINTR  The system call was interrupted by a signal that  was  caught
                   before a valid connection arrived; see signal(7).

            EINVAL Socket  is  not  listening  for  connections,  or  addrlen is
                   invalid (e.g., is negative).

            EINVAL invalid value in flags.

            EMFILE The per-process limit  of  open  file  descriptors  has  been
                   reached.

            ENFILE The  system  limit on the total number of open files has been
                   reached.

            ENOBUFS, ENOMEM
                   Not enough free memory.  This often  means  that  the  memory
                   allocation is limited by the socket buffer limits, not by the
                   system memory.

            ENOTSOCK
                   The descriptor references a file, not a socket.

            EOPNOTSUPP
                   The referenced socket is not of type SOCK_STREAM.

            EPROTO Protocol error.

            In addition, Linux accept() may fail if:

            EPERM  Firewall rules forbid connection.

            In addition, network errors for the new socket and  as  defined  for
            the  protocol  may  be  returned.   Various Linux kernels can return
            other  errors  such  as  ENOSR,  ESOCKTNOSUPPORT,   EPROTONOSUPPORT,
            ETIMEDOUT.  The value ERESTARTSYS may be seen during a trace.

     **************************************************************************/

    public int accept ( ISelectable listening_socket,
                        ref InAddr remote_address, SocketFlags flags = SocketFlags.None )
    {
        socklen_t addrlen;

        return super.accept(listening_socket,
                            cast (sockaddr*) &remote_address, addrlen, flags);
    }

    /**************************************************************************

        Calls accept() to accept a connection from a listening socket, sets
        this.fd to the accepted socket file descriptor.

        Params:
            listening_socket = the listening socket to accept the new connection
                               from
            remote_address   = filled in with the address of the peer socket, as
                               known to the communications layer
            nonblocking      = true: make the accepted socket nonblocking,
                               false: leave it blocking

        Returns:
            the file descriptor of the accepted socket on success or -1 on
            failure. On failure errno is set appropriately.

     **************************************************************************/

    public int accept ( ISelectable listening_socket,
                        ref InAddr remote_address, bool nonblocking )
    {
        const SocketFlags[2] flags = [SocketFlags.None, SocketFlags.SOCK_NONBLOCK];

        return this.accept(listening_socket, remote_address, flags[nonblocking]);
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int accept ( ISelectable listening_socket,
                                 sockaddr* remote_address, out socklen_t addrlen,
                                 SocketFlags flags = SocketFlags.None )
    {
        return super.accept(listening_socket, remote_address, addrlen, flags);
    }

    /**************************************************************************

        Connects this socket the specified address. This socket needs to have
        been created by socket().

        If  this socket is of type SOCK_DGRAM  then the  address  is the one  to
        which datagrams are sent by default, and the  only  address  from  which
        datagrams  are  received.   If  the  socket  is  of  type SOCK_STREAM or
        SOCK_SEQPACKET, this call attempts to make a connection  to  the  socket
        that is bound to the address specified by addr.

        Generally,  connection-based protocol sockets may successfully connect()
        only once; connectionless protocol sockets may  use  connect()  multiple
        times  to change their association.  Connectionless sockets may dissolve
        the association by connecting to an address with the sa_family member of
        sockaddr set to AF_UNSPEC (supported on Linux since kernel 2.2).

        Params:
            remote_address = remote address

        Returns:
            0 on success or -1 on failure. On error failure is set
            appropriately.

        Errors:
            The  following  are  general socket errors only.  There may be other
            domain-specific error codes.

            EACCES For Unix domain sockets, which are  identified  by  pathname:
                   Write permission is denied on the socket file, or search per‐
                   mission is denied for one of the directories in the path pre‐
                   fix.  (See also path_resolution(7).)

            EACCES, EPERM
                   The user tried to connect to a broadcast address without hav‐
                   ing the socket  broadcast  flag  enabled  or  the  connection
                   request failed because of a local firewall rule.

            EADDRINUSE
                   Local address is already in use.

            EAGAIN No more free local ports or insufficient entries in the rout‐
                   ing    cache.    For   AF_INET   see   the   description   of
                   /proc/sys/net/ipv4/ip_local_port_range ip(7) for  information
                   on how to increase the number of local ports.

            EALREADY
                   The  socket  is nonblocking and a previous connection attempt
                   has not yet been completed.

            EBADF  The file descriptor is not a valid index  in  the  descriptor
                   table.

            ECONNREFUSED
                   No-one listening on the remote address.

            EFAULT The  socket  structure  address is outside the user's address
                   space.

            EINPROGRESS
                   The socket is nonblocking and the connection cannot  be  com‐
                   pleted  immediately.   It is possible to select(2) or poll(2)
                   for completion by selecting the socket  for  writing.   After
                   select(2)  indicates  writability,  use getsockopt(2) to read
                   the SO_ERROR option at level SOL_SOCKET to determine  whether
                   connect() completed successfully (SO_ERROR is zero) or unsuc‐
                   cessfully (SO_ERROR is one of the usual  error  codes  listed
                   here, explaining the reason for the failure).

            EINTR  The  system call was interrupted by a signal that was caught;
                   see signal(7).

            EISCONN
                   The socket is already connected.

            ENETUNREACH
                   Network is unreachable.

            ENOTSOCK
                   The file descriptor is not associated with a socket.

            ETIMEDOUT
                   Timeout while attempting connection.  The server may  be  too
                   busy to accept new connections.  Note that for IP sockets the
                   timeout may be very long when syncookies are enabled  on  the
                   server.

     **************************************************************************/

    public int connect ( InAddr remote_address )
    {
        return super.connect(cast (sockaddr*) &remote_address);
    }

    /**************************************************************************

        Connects this socket the specified address and port. This socket needs
        to have been created by socket().

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

    public int connect ( char[] remote_ip_address, ushort remote_port )
    {
        InetAddress!(IPv6) in_address;

        sockaddr* remote_address = in_address(remote_ip_address, remote_port);

        return remote_address? super.connect(remote_address) : -1;
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int connect ( sockaddr* remote_address )
    {
        return super.connect(remote_address);
    }

    /**************************************************************************

        Obtains the current address to which this socket is bound.

        Params:
            local_address = filled in with the address of the local socket, as
                            known to the communications layer, depending on the
                            IP version of this class

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF The argument sockfd is not a valid descriptor.

            EFAULT The local_address argument points to memory not in a valid
                part of the process address space.

            ENOBUFS
                Insufficient resources were available in the system to perform
                the operation.

            ENOTSOCK
                this.fd is a file, not a socket.

     **************************************************************************/

    public int getsockname ( out InAddr local_address )
    {
        socklen_t addrlen;

        return super.getsockname(cast (sockaddr*) &local_address, addrlen);
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int getsockname ( sockaddr* local_address, out socklen_t addrlen )
    {
        return super.getsockname(local_address, addrlen);
    }

    /**************************************************************************

        Obtains the address of the peer connected to this socket.

        Params:
            remote_address = filled in with the address of the remote socket, as
                             known to the communications layer, depending on the
                             IP version of this class

        Returns:
            0 success or -1 on failure. On failure errno is set appropriately.

        Errors:
            EBADF this.fg is not a valid descriptor.

            EFAULT The remote_address argument points to memory not in a valid
                part of the process address space.

            ENOBUFS
                Insufficient resources were available in the system to perform
                the operation.

            ENOTSOCK
                this.fd is a file, not a socket.

     **************************************************************************/

    public int getpeername ( out InAddr remote_address )
    {
        socklen_t addrlen;

        return super.getpeername(cast (sockaddr*) &remote_address, addrlen);
    }

    /**************************************************************************

        Overriding wrapper to satisfy overload-override rules of D.

     **************************************************************************/

    public override int getpeername ( sockaddr* remote_address, out socklen_t addrlen )
    {
        return super.getpeername(remote_address, addrlen);
    }
}

/******************************************************************************

       Linux specific extension of accept(), accepting additional flags.
       The following cites the manpage:

       The  accept()  system  call is used with connection-based socket types
       (SOCK_STREAM,  SOCK_SEQPACKET).   It  extracts  the  first  connection
       request  on the queue of pending connections for the listening socket,
       sockfd, creates a  new  connected  socket,  and  returns  a  new  file
       descriptor  referring to that socket.  The newly created socket is not
       in the listening state.  The original socket sockfd is  unaffected  by
       this call.

       The  argument sockfd is a socket that has been created with socket(2),
       bound to a local address with bind(2), and is  listening  for  connec‐
       tions after a listen(2).

       The  argument  addr is a pointer to a sockaddr structure.  This struc‐
       ture is filled in with the address of the peer socket, as known to the
       communications  layer.   The exact format of the address returned addr
       is determined by the socket's address family (see  socket(2)  and  the
       respective  protocol man pages).  When addr is NULL, nothing is filled
       in; in this case, addrlen is not used, and should also be NULL.

       The addrlen argument is a value-result argument: the caller must  ini‐
       tialize  it to contain the size (in bytes) of the structure pointed to
       by addr; on return it  will  contain  the  actual  size  of  the  peer
       address.

       The returned address is truncated if the buffer provided is too small;
       in this case, addrlen will return a value greater than was supplied to
       the call.

       If  no pending connections are present on the queue, and the socket is
       not marked as nonblocking, accept() blocks the caller until a  connec‐
       tion  is  present.  If the socket is marked nonblocking and no pending
       connections are present on the queue, accept() fails  with  the  error
       EAGAIN or EWOULDBLOCK.

       If  flags is 0, then accept4() is the same as accept().  The following
       values can be bitwise ORed in flags to obtain different behavior:

       SOCK_NONBLOCK   Set the O_NONBLOCK file status flag on  the  new  open
                       file  description.   Using this flag saves extra calls
                       to fcntl(2) to achieve the same result.

       SOCK_CLOEXEC    Set the close-on-exec (FD_CLOEXEC)  flag  on  the  new
                       file descriptor.  See the description of the O_CLOEXEC
                       flag in open(2) for reasons why this may be useful.

    RETURN VALUE
       On success, these system calls return a nonnegative integer that is  a
       descriptor  for  the  accepted  socket.  On error, -1 is returned, and
       errno is set appropriately.

   Error Handling
       Linux accept() (and accept4()) passes already-pending  network  errors
       on  the new socket as an error code from accept().  This behavior dif‐
       fers from other BSD socket implementations.   For  reliable  operation
       the  application should detect the network errors defined for the pro‐
       tocol after accept() and treat them like EAGAIN by retrying.  In  case
       of  TCP/IP these are ENETDOWN, EPROTO, ENOPROTOOPT, EHOSTDOWN, ENONET,
       EHOSTUNREACH, EOPNOTSUPP, and ENETUNREACH.

    ERRORS
       EAGAIN or EWOULDBLOCK
              The socket is marked nonblocking and no connections are present
              to  be  accepted.   POSIX.1-2001  allows  either  error  to  be
              returned for this case, and does not require these constants to
              have the same value, so a portable application should check for
              both possibilities.

       EBADF  The descriptor is invalid.

       ECONNABORTED
              A connection has been aborted.

       EFAULT The addr argument is not in a writable part of the user address
              space.

       EINTR  The  system  call  was  interrupted by a signal that was caught
              before a valid connection arrived; see signal(7).

       EINVAL Socket is not listening for connections, or addrlen is  invalid
              (e.g., is negative).

       EINVAL (accept4()) invalid value in flags.

       EMFILE The  per-process  limit  of  open  file  descriptors  has  been
              reached.

       ENFILE The system limit on the total number of  open  files  has  been
              reached.

       ENOBUFS, ENOMEM
              Not enough free memory.  This often means that the memory allo‐
              cation is limited by the socket buffer limits, not by the  sys‐
              tem memory.

       ENOTSOCK
              The descriptor references a file, not a socket.

       EOPNOTSUPP
              The referenced socket is not of type SOCK_STREAM.

       EPROTO Protocol error.

       In addition, Linux accept() may fail if:

       EPERM  Firewall rules forbid connection.

       In  addition, network errors for the new socket and as defined for the
       protocol may be returned.  Various  Linux  kernels  can  return  other
       errors  such  as  ENOSR,  ESOCKTNOSUPPORT, EPROTONOSUPPORT, ETIMEDOUT.
       The value ERESTARTSYS may be seen during a trace.


 ******************************************************************************/

extern (C) private int accept4(int sockfd, sockaddr* addr, socklen_t* addrlen,
                               SocketFlags flags = SocketFlags.None);
