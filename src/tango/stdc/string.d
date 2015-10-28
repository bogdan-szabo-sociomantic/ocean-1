module tango.stdc.string;

public import core.stdc.string;

version (D_Version2)
{
    public import core.stdc.wchar_;
}

version (GLIBC) public import tango.stdc.gnu.string;

version (Posix)
{
    extern (C):

    char *strsignal(int sig);
    int strcasecmp(in char *s1, in char *s2);
    int strncasecmp(in char *s1, in char *s2, size_t n);
}
