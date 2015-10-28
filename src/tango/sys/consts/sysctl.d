module tango.sys.consts.sysctl;

version (linux)
         public import tango.sys.linux.consts.sysctl;
else
version (freebsd)
         public import tango.sys.freebsd.consts.sysctl;
else
version (darwin)
         public import tango.sys.darwin.consts.sysctl;
else
version (solaris)
         public import tango.sys.solaris.consts.sysctl;

