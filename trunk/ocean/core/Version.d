/******************************************************************************

    Ocean version

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt

    Description:

    Checks whether the version string of this Ocean version was passed to the
    compiler. If not, prints a compile time message.

    Usage:

    1. Add
                                                                             ---
            import ocean.core.Version
                                                                             ---
       to main module.

    2. Add
                                                                             ---
            -version=version_identifier
                                                                             ---
     to DMD command line when compiling. This is done by append it to DFLAGS in
     dsss.conf.

 ******************************************************************************/

module ocean.core.Version;

version (ocean_rev4711) {}
else
{
    pragma (msg, "OceanVersion: No or different version requested than ocean_rev4711");
}
