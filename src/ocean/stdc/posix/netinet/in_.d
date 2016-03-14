module ocean.stdc.posix.netinet.in_;

public import core.sys.posix.netinet.in_;

static if (__VERSION__ < 2067)
{
    enum
    {
        IPPROTO_PUP = 12, /* PUP protocol.  */
        IPPROTO_IGMP = 2, /* Internet Group Management Protocol. */
        IPPROTO_IDP = 22, /* XNS IDP protocol.  */
    }
}
