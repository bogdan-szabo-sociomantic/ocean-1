/*******************************************************************************

    Copyright:
        Copyright (c) 2004-2009 Tango contributors.
        Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.
    License:
        Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
        See LICENSE_TANGO.txt for details.
*******************************************************************************/


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

