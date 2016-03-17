module ocean.sys.consts.sysctl;

version (linux)
         public import ocean.sys.linux.consts.sysctl;
else
version (freebsd)
         public import ocean.sys.freebsd.consts.sysctl;
else
version (darwin)
         public import ocean.sys.darwin.consts.sysctl;
else
version (solaris)
         public import ocean.sys.solaris.consts.sysctl;

