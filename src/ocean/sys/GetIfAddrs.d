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
debug import tango.io.Stdout;

/*******************************************************************************

    Returns IP address for the network interface.

    Params:
        interface_name = Name of the interface (e.g. eth0)

    Returns:
        IP address of the interface as a string, if it could be resolved,
        otherwise an empty string.

*******************************************************************************/

char[] getAddressForInterface(char[] interface_name)
{
    ifaddrs* ifaddr;

    // Try to fetch a linked list of interfaces and their adresses
    if (getifaddrs(&ifaddr) == -1)
    {
        return "";
    }

    // ifaddr is allocated, and it needs to be freed!
    scope(exit) freeifaddrs(ifaddr);

    // Iterate through each interface and check if the interface
    // is the one that we're looking for.

    for (auto ifa = ifaddr; ifa !is  null; ifa = ifa.ifa_next)
    {

        /***********************************************************************

            From the `getifaddrs` man page:
                The ifa_addr field points to a structure containing the
                interface address.  (The sa_family subfield should be consulted
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

        // IPv6 and IPv4 interfaces
        auto family = ifa.ifa_addr.sa_family;

        if (family == AF_INET || family == AF_INET6)
        {
            char[NI_MAXHOST] buffer;

            // Use getnameinfo to get the interface address, regardless
            // of the family

            auto result = getnameinfo(ifa.ifa_addr,
                                       (family == AF_INET) ?
                                            sockaddr_in.sizeof : sockaddr_in6.sizeof,
                                       buffer.ptr,
                                       buffer.length,
                                       null,
                                       0,
                                       NI_NUMERICHOST);

            // Check the result code
            if (result == 0)
            {
                return StringC.toDString(buffer).dup;
            }

            break;
        }
    }

    return "";
}

