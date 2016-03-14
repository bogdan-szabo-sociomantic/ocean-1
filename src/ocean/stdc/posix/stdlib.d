module ocean.stdc.posix.stdlib;

public import core.sys.posix.stdlib;

version (GLIBC) public import tango.stdc.posix.gnu.stdlib;

extern (C) char* mkdtemp(char*);
