/*******************************************************************************

    Helper class to store version information.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.VersionInfo;


import tango.transition;


/*******************************************************************************

    Associative array which contains version information.

    Typically this array should contain the keys:
     * build_author
     * build_date
     * dmd
     * gc
     * lib_*

    Where lib_* are considered to be libraries used by this program.

    This is usually generated automatically, this is why this kind of *duck
    typing* is used (to avoid a dependency between the generator and this
    library).

*******************************************************************************/

alias istring[istring] VersionInfo;

