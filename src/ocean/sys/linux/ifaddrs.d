module ocean.sys.linux.ifaddrs;

import ocean.stdc.posix.sys.socket;

version (linux)
{
    extern (C):

    struct ifaddrs
    {
        ifaddrs*         ifa_next;
        char*            ifa_name;
        uint      ifa_flags;
        sockaddr* ifa_addr;
        sockaddr* ifa_netmask;

        union
        {
            sockaddr* ifu_broadaddr;
            sockaddr* if_dstaddr;
        }

        void* ifa_data;
    };

    int getifaddrs(ifaddrs** );
    void freeifaddrs(ifaddrs* );
}

