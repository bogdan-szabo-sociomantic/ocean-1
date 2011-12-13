/*******************************************************************************

    Helper class to store version information.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.VersionInfo;



/*******************************************************************************

    Helper class to store version information.

    This struct is meant to be filled automatically by the mkversion.sh script.

    See the module documentation for details.

*******************************************************************************/

class VersionInfo
{
    public char[]         revision     = "<unknown>";
    public char[]         gc           = "<unknown>";
    public char[]         build_date   = "<unknown>";
    public char[]         build_author = "<unknown>";
    public char[][char[]] libraries;
}

