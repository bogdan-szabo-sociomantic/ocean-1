module tango.stdc.posix.sys.socket;

public import core.sys.posix.sys.socket;
public import core.sys.posix.netinet.tcp;
public import core.sys.posix.netinet.in_;
public import core.sys.posix.netdb;

version (GLIBC) public import tango.stdc.posix.gnu.socket;

enum
{
    // OptionLevel.IP settings
    IP_MULTICAST_TTL = 33 ,
    IP_MULTICAST_LOOP = 34 ,
    IP_ADD_MEMBERSHIP = 35 ,
    IP_DROP_MEMBERSHIP = 36,
}

enum {SOCKET_ERROR = -1}

enum
{
    SOCK_NONBLOCK = 0x800, /* Atomically mark descriptor(s) as
                              non-blocking.  */
    SOCK_CLOEXEC  = 0x8_0000, /* Atomically set close-on-exec flag for the
                                 new descriptor(s).  */
}

static if (__VERSION__ < 2067)
{
    enum
    {
        AF_IPX = 4,
        AF_APPLETALK = 5,
    }
}
