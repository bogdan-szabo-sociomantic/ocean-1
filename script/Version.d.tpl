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

private import ocean.util.Main;

public VersionInfo Version;

static this()
{
    // TODO: Version.release = "@RELEASE@";
    Version.revision     = "@REVISION@";
    Version.gc           = "@GC@";
    Version.build_date   = "@DATE@";
    Version.build_author = "@AUTHOR@";
@LIBRARIES@
}

