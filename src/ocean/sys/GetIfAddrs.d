/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Functions to get IP address from the given interface.

*******************************************************************************/

module ocean.sys.GetIfAddrs;

/*******************************************************************************

    Imports

*******************************************************************************/

import tango.stdc.posix.sys.socket;
import tango.sys.linux.ifaddrs;
import tango.stdc.string;
import ocean.text.util.StringC;
import tango.sys.linux.consts.socket: AF_INET, AF_INET6;
import tango.stdc.posix.netinet.in_: sockaddr_in, sockaddr_in6;
import tango.stdc.posix.arpa.inet;
import ocean.core.Test;
import ocean.core.TypeConvert;
import tango.stdc.errno;
debug import tango.io.Stdout;

/*******************************************************************************

    Exception type to be thrown when fetching the IP address(es) for the
    interface fails.

*******************************************************************************/
class ResolveIPException: Exception
{
    /**************************************************************************

        Constructor. Construct the `ResolveIPException instance`.

        Params:
            file = file in which exception has been thrown
            line = line where exception has been thrown
            msg = error description message
            errno = error code value

    **************************************************************************/

    public this(char[] file, long line, char[] msg, int errno)
    {
        super(msg, file, line);
        this.errno = errno;
    }

    /**************************************************************************

        Error code from the failed system call.

    **************************************************************************/

    public int errno;
}

/*******************************************************************************

    Returns IP addresses for the network interface.

    Params:
        interface_name = Name of the interface (e.g. eth0)
        ipv6 = true: fetch IPv6 addresses, false: IPv4

    Returns:
        IP addresses of the interface for the given family as strings,
        if they could be resolved, otherwise an empty array.

*******************************************************************************/

char[][] getAddrsForInterface( char[] interface_name, bool ipv6 = false )
{
    char[][] addresses;
    bool delegate_called = false;

    auto ret = getAddrsForInterface(interface_name, ipv6,
        (char[] address, int getnameinfo_status)
        {
            delegate_called = true;

            if (getnameinfo_status != 0)
            {
                throw new ResolveIPException(__FILE__, __LINE__,
                    "getnameinfo failed", getnameinfo_status);
            }

            if (address.length)
            {
                addresses ~= address.dup;
            }

            return false;
        });

    if (ret && !delegate_called)
    {
        throw new ResolveIPException(__FILE__, __LINE__, "getifaddrs failed", errno);
    }

    return addresses;
}

/*******************************************************************************

    Returns IP address for the network interface.

    Params:
        interface_name = Name of the interface (e.g. eth0)

    Returns:
        IP address of the interface as a string, if it could be resolved,
        otherwise an empty string.

*******************************************************************************/

deprecated char[] getAddressForInterface(char[] interface_name)
{
    char[] address_out = null;

    getAddrsForInterface(interface_name, false,
        (char[] address, int getnameinfo_status)
        {
            if (address.length)
            {
                address_out = address.dup;
                return true;
            }
            else
            {
                return false;
            }
        });

    return address_out;
}

/*******************************************************************************

    Iterates over IP addresses for the network interface.

    Obtains the network address of the local system from getifaddrs() and calls
    dg with a host and service name string for each of these addresses. If host
    and service name string formatting failed for an address, dg is called with
    a null address and the status code of the conversion function,
    getnameinfo(). See the manpage of getnameinfo() for its status codes.

    dg should return false to continue or true to stop iteration.

    If dg isn't called and return value is true, getifaddrs() has failed;
    in this case check errno and see the getnameinfo() manpage.

    Params:
        interface_name = Name of the interface (e.g. eth0)
        ipv6 = true: fetch IPv6 addresses, false: IPv4
        dg = iteration delegate

    Returns:
        true if either dg returned true to stop the iteration or getifaddrs()
        failed or false if the iteration finished normally.

*******************************************************************************/

bool getAddrsForInterface( char[] interface_name, bool ipv6,
                           bool delegate ( char[] address,
                                           int    getnameinfo_status ) dg )
{
    ifaddrs* ifaddr;

    // Try to fetch a linked list of interfaces and their adresses
    if (getifaddrs(&ifaddr) == -1)
    {
        return true;
    }

    // ifaddr is allocated, and it needs to be freed!
    scope(exit) freeifaddrs(ifaddr);

    auto salen  = ipv6? sockaddr_in6.sizeof : sockaddr_in.sizeof,
         family = ipv6? AF_INET6 : AF_INET;

    // Iterate through each interface and check if the interface
    // is the one that we're looking for.

    for (auto ifa = ifaddr; ifa !is null; ifa = ifa.ifa_next)
    {
        /***********************************************************************

            From the `getifaddrs` man page:
            The ifa_addr field points to a structure containing the
            interface address. (The sa_family subfield should be consulted
            to determine the format of the address structure.) This field
            may contain a null pointer.

        ***********************************************************************/

        if(!ifa.ifa_addr)
        {
            continue;
        }

        if (interface_name != StringC.toDString(ifa.ifa_name))
        {
            continue;
        }

        if (ifa.ifa_addr.sa_family != family)
        {
            continue;
        }

        char[NI_MAXHOST] buffer;

        // Use getnameinfo to get the interface address

        auto result = getnameinfo(ifa.ifa_addr,
                                   castFrom!(size_t).to!(uint)(salen),
                                   buffer.ptr,
                                   buffer.length,
                                   null,
                                   0,
                                   NI_NUMERICHOST);

        // Check the result code and invoke the iteration delegate
        if (dg(result? null : StringC.toDString(buffer.ptr), result))
        {
            return true;
        }
    }

    return false;
}
