/*******************************************************************************

        copyright:      Copyright (c) 2005 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: March 2005

        author:         Kris

*******************************************************************************/

module ocean.io.model.IFile;

import ocean.transition;

/*******************************************************************************

        Generic file-oriented attributes.

*******************************************************************************/

interface FileConst
{
        /***********************************************************************

                A set of file-system specific constants for file and path
                separators (chars and strings).

                Keep these constants mirrored for each OS.

        ***********************************************************************/

        version (Posix)
        {
                ///
                enum : char
                {
                        /// The current directory character.
                        CurrentDirChar = '.',

                        /// The file separator character.
                        FileSeparatorChar = '.',

                        /// The path separator character.
                        PathSeparatorChar = '/',

                        /// The system path character.
                        SystemPathChar = ':',
                }

                /// The parent directory string.
                const ParentDirString = "..";

                /// The current directory string.
                const CurrentDirString = ".";

                /// The file separator string.
                const FileSeparatorString = ".";

                /// The path separator string.
                const PathSeparatorString = "/";

                /// The system path string.
                const SystemPathString = ":";

                /// The newline string.
                const NewlineString = "\n";
        }
}

/*******************************************************************************

        Passed around during file-scanning.

*******************************************************************************/

struct FileInfo
{
        istring         path,
                        name;
        ulong           bytes;
        bool            folder,
                        hidden,
                        system;
}
