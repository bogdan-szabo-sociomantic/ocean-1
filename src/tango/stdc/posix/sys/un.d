module tango.stdc.posix.sys.un;

public import core.sys.posix.sys.un;

extern (C):

const UNIX_PATH_MAX = 108;

align(1)
struct sockaddr_un
{
        align(1):
        ushort sun_family;
        char[UNIX_PATH_MAX] sun_path;
}
