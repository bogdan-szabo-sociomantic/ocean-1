module tango.stdc.posix.fcntl;

public import core.sys.posix.fcntl;

import core.sys.posix.config;

enum { O_NOFOLLOW = 0x20000 } // 0400000
enum { O_DIRECT  = 0x4000 }

enum { POSIX_FADV_NORMAL = 0 }
enum { POSIX_FADV_RANDOM = 1 }
enum { POSIX_FADV_SEQUENTIAL = 2 }
enum { POSIX_FADV_WILLNEED = 3 }
enum { POSIX_FADV_DONTNEED = 4 }
enum { POSIX_FADV_NOREUSE = 5 }

static if( __USE_LARGEFILE64 )
{
    enum { O_LARGEFILE = 0x8000 }
    enum { F_GETLK = 12 }
    enum { F_SETLK = 13 }
    enum { F_SETLKW = 14 }
}
else
{
    enum { O_LARGEFILE = 0 }
    enum { F_GETLK = 5  }
    enum { F_SETLK = 6  }
    enum { F_SETLKW = 7 }
}
