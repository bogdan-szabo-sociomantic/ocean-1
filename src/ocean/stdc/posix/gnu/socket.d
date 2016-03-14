/*******************************************************************************

    glibc socket functions.

*******************************************************************************/

module ocean.stdc.posix.gnu.socket;

import tango.stdc.posix.sys.socket;

version (GLIBC):

extern (C):

int accept4(int, sockaddr*, socklen_t*, int);
