module ocean.stdc.posix.netdb;

public import core.sys.posix.netdb;

enum
{
    AI_MASK = (AI_PASSIVE | AI_CANONNAME | AI_NUMERICHOST | AI_NUMERICSERV | AI_ADDRCONFIG),
    AI_DEFAULT = (AI_V4MAPPED | AI_ADDRCONFIG),
}

enum
{
    EAI_NODATA         = -5,
}
