/*******************************************************************************

    Subclass of tango.io.FilePath to provide some extra functionality

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.io.FilePath;



/*******************************************************************************

    Imports.

*******************************************************************************/

import tango.io.FilePath;

import tango.io.Path : FS;

import tango.stdc.posix.unistd : link;



/*******************************************************************************

    Models a file path.

    See tango.io.FilePath module for more details. The purpose of this class is
    only to provide missing functionality.

*******************************************************************************/

public class FilePath : tango.io.FilePath.FilePath
{

    /***********************************************************************

        Create a FilePath from a copy of the provided string.

        See tango.io.FilePath.FilePath constructor for details.

    ***********************************************************************/

    public this (cstring filepath = null)
    {
        super (filepath);
    }

    /***********************************************************************

        Create a new name for a file (also known as -hard-linking)

        Params:
            src_path = FilePath with the file name to be renamed
            dst_path = FilePath with the new file name

        Returns:
            this.path set to the new destination location if it was moved,
            null otherwise.

        See_Also:
            man 2 link

    ***********************************************************************/

    public final FilePath link ( FilePath dst )
    {
        if (.link(this.cString().ptr, dst.cString().ptr) is -1)
        {
            FS.exception(this.toString());
        }

        return this;
    }

}

