/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: November 2005

        author:         Kris

*******************************************************************************/

module tango.sys.Common;

import tango.transition;

version (linux)
        {
        public import tango.sys.linux.linux;
        alias tango.sys.linux.linux posix;
        }

version (darwin)
        {
        public import tango.sys.darwin.darwin;
        alias tango.sys.darwin.darwin posix;
        }
version (freebsd)
        {
        public import tango.sys.freebsd.freebsd;
        alias tango.sys.freebsd.freebsd posix;
        }
version (solaris)
        {
        public import tango.sys.solaris.solaris;
        alias tango.sys.solaris.solaris posix;
        }

/*******************************************************************************

        Stuff for sysErrorMsg(), kindly provided by Regan Heath.

*******************************************************************************/

version (Posix)
        {
        import tango.stdc.errno;
        import tango.stdc.string;
        }
else
   {
   pragma (msg, "Unsupported environment; neither Win32 or Posix is declared");
   static assert(0);
   }


/*******************************************************************************

*******************************************************************************/

struct SysError
{
        /***********************************************************************

        ***********************************************************************/

        static uint lastCode ()
        {
             return errno;
        }

        /***********************************************************************

        ***********************************************************************/

        static istring lastMsg ()
        {
                return lookup (lastCode);
        }

        /***********************************************************************

        ***********************************************************************/

        static istring lookup (uint errcode)
        {
                char[] text;

                size_t  r;
                char* pemsg;

                pemsg = strerror(errcode);
                r = strlen(pemsg);

                /* Remove \r\n from error string */
                if (pemsg[r-1] == '\n') r--;
                if (pemsg[r-1] == '\r') r--;
                text = pemsg[0..r].dup;

                return assumeUnique(text);
        }
}
