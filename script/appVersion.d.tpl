/*******************************************************************************

    Version information generated at compile time.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2011: Initial release

    authors:        Leandro Lucarella

    This file is automatically generated.

    DO NOT CHANGE, IT WILL BE OVERWRITTEN

    DO NOT ADD TO THE REPOSITORY

*******************************************************************************/

module @MODULE@;

import ocean.core.VersionIdentifiers;
import ocean.util.app.ext.VersionInfo;
import tango.core.Version: getVersionString;

public VersionInfo Version;

static this()
{
    Version = new VersionInfo;
    // TODO: Version.release = "@RELEASE@";
    Version.revision     = "@REVISION@";
    Version.gc           = "@GC@";
    Version.build_date   = "@DATE@ "  ~ __TIME__.stringof;
    Version.build_author = "@AUTHOR@";
    Version.dmd_version  = "@DMD@";
    // TODO: Version.version_flags = [@VERSIONS@];
    versionIdentifiers(( char[] version_name )
    {
        Version.version_flags ~= version_name;
    });
    static if (is(typeof(getVersionString)))
    {
        Version.libraries["tango"] = getVersionString();
    }
@LIBRARIES@
}

// vim: set filetype=d :
