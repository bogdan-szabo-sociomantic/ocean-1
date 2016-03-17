/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD:
                        AFL 3.0:

        version:        Mar 2004: Initial release
        version:        Feb 2007: Now using mutating paths

        authors:        Kris, Chris Sauls (Win95 file support)

*******************************************************************************/

module ocean.io.FileSystem;

import ocean.transition;

import ocean.sys.Common;

import ocean.io.FilePath_tango;

import ocean.core.Exception_tango;

import ocean.io.Path : standard, native;

/*******************************************************************************

*******************************************************************************/

version (Posix)
        {
        import ocean.stdc.string;
        import ocean.stdc.posix.unistd,
                       ocean.stdc.posix.sys.statvfs;

        import ocean.io.device.File;
        import Integer = ocean.text.convert.Integer_tango;
        }

/*******************************************************************************

        Models an OS-specific file-system. Included here are methods to
        manipulate the current working directory, and to convert a path
        to its absolute form.

*******************************************************************************/

struct FileSystem
{
        /***********************************************************************

                Convert the provided path to an absolute path, using the
                current working directory where prefix is not provided.
                If the given path is already an absolute path, return it
                intact.

                Returns the provided path, adjusted as necessary

                deprecated: See FilePath.absolute().

        ***********************************************************************/

        deprecated static FilePath toAbsolute (FilePath target, char[] prefix=null)
        {
                if (! target.isAbsolute)
                   {
                   if (prefix is null)
                       prefix = getDirectory;

                   target.prepend (target.padded(prefix));
                   }
                return target;
        }

        /***********************************************************************

                Convert the provided path to an absolute path, using the
                current working directory where prefix is not provided.
                If the given path is already an absolute path, return it
                intact.

                Returns the provided path, adjusted as necessary

                deprecated: See FilePath.absolute().

        ***********************************************************************/

        deprecated static istring toAbsolute (char[] path, char[] prefix=null)
        {
                scope target = new FilePath (path);
                return toAbsolute (target, prefix).toString;
        }

        /***********************************************************************

                Compare to paths for absolute equality. The given prefix
                is prepended to the paths where they are not already in
                absolute format (start with a '/'). Where prefix is not
                provided, the current working directory will be used

                Returns true if the paths are equivalent, false otherwise

                deprecated: See FilePath.equals().

        ***********************************************************************/

        deprecated static bool equals (char[] path1, char[] path2, char[] prefix=null)
        {
                scope p1 = new FilePath (path1);
                scope p2 = new FilePath (path2);
                return (toAbsolute(p1, prefix) == toAbsolute(p2, prefix)) is 0;
        }

        /***********************************************************************

        ***********************************************************************/

        private static void exception (istring msg)
        {
                throw new IOException (msg);
        }

        /***********************************************************************

        ***********************************************************************/

        version (Posix)
        {
                /***************************************************************

                        Set the current working directory.

                        deprecated: See Environment.cwd().

                ***************************************************************/

                deprecated static void setDirectory (char[] path)
                {
                        char[512] tmp = void;
                        tmp [path.length] = 0;
                        tmp[0..path.length] = path;

                        if (ocean.stdc.posix.unistd.chdir (tmp.ptr))
                            exception ("Failed to set current directory");
                }

                /***************************************************************

                        Return the current working directory.

                        deprecated: See Environment.cwd().

                ***************************************************************/

                deprecated static char[] getDirectory ()
                {
                        char[512] tmp = void;

                        char *s = ocean.stdc.posix.unistd.getcwd (tmp.ptr, tmp.length);
                        if (s is null)
                            exception ("Failed to get current directory");

                        auto path = s[0 .. strlen(s)+1].dup;
                        path[$-1] = '/';
                        return path;
                }

                /***************************************************************

                        List the set of root devices.

                 ***************************************************************/

                static istring[] roots ()
                {
                        version(darwin)
                        {
                            assert(0);
                        }
                        else
                        {
                            istring path = "";
                            istring[] list;
                            int spaces;

                            auto fc = new File("/etc/mtab");
                            scope (exit)
                                   fc.close;

                            auto content = new char[cast(int) fc.length];
                            fc.input.read (content);

                            for(int i = 0; i < content.length; i++)
                            {
                                if(content[i] == ' ') spaces++;
                                else if(content[i] == '\n')
                                {
                                    spaces = 0;
                                    list ~= path;
                                    path = "";
                                }
                                else if(spaces == 1)
                                {
                                    if(content[i] == '\\')
                                    {
                                        path ~= cast(char) Integer.parse(content[++i..i+3], 8u);
                                        i += 2;
                                    }
                                    else path ~= content[i];
                                }
                            }

                            return list;
                        }
                }

                /***************************************************************

                        Request how much free space in bytes is available on the
                        disk/mountpoint where folder resides.

                        If a quota limit exists for this area, that will be taken
                        into account unless superuser is set to true.

                        If a user has exceeded the quota, a negative number can
                        be returned.

                        Note that the difference between total available space
                        and free space will not equal the combined size of the
                        contents on the file system, since the numbers for the
                        functions here are calculated from the used blocks,
                        including those spent on metadata and file nodes.

                        If actual used space is wanted one should use the
                        statistics functionality of ocean.io.vfs.

                        See_also: totalSpace()

                        Since: 0.99.9

                ***************************************************************/

                static long freeSpace(char[] folder, bool superuser = false)
                {
                    scope fp = new FilePath(folder);
                    statvfs_t info;
                    int res = statvfs(fp.native.cString.ptr, &info);
                    if (res == -1)
                        exception ("freeSpace->statvfs failed:"
                                   ~ SysError.lastMsg);

                    if (superuser)
                        return cast(long)info.f_bfree *  cast(long)info.f_bsize;
                    else
                        return cast(long)info.f_bavail * cast(long)info.f_bsize;
                }

                /***************************************************************

                        Request how large in bytes the
                        disk/mountpoint where folder resides is.

                        If a quota limit exists for this area, then
                        that quota can be what will be returned unless superuser
                        is set to true. On Posix systems this distinction is not
                        made though.

                        NOTE Access to this information when _superuser is
                        set to true may only be available if the program is
                        run in superuser mode.

                        See_also: freeSpace()

                        Since: 0.99.9

                ***************************************************************/

                static long totalSpace(char[] folder, bool superuser = false)
                {
                    scope fp = new FilePath(folder);
                    statvfs_t info;
                    int res = statvfs(fp.native.cString.ptr, &info);
                    if (res == -1)
                        exception ("totalSpace->statvfs failed:"
                                   ~ SysError.lastMsg);

                    return cast(long)info.f_blocks *  cast(long)info.f_frsize;
                }
        }
}


/******************************************************************************

******************************************************************************/

debug (FileSystem)
{
        import ocean.io.Stdout_tango;

        static void foo (FilePath path)
        {
        Stdout("all: ") (path).newline;
        Stdout("path: ") (path.path).newline;
        Stdout("file: ") (path.file).newline;
        Stdout("folder: ") (path.folder).newline;
        Stdout("name: ") (path.name).newline;
        Stdout("ext: ") (path.ext).newline;
        Stdout("suffix: ") (path.suffix).newline.newline;
        }

        void main()
        {
        Stdout.formatln ("dir: {}", FileSystem.getDirectory);

        auto path = new FilePath (".");
        foo (path);

        path.set ("..");
        foo (path);

        path.set ("...");
        foo (path);

        path.set (r"/x/y/.file");
        foo (path);

        path.suffix = ".foo";
        foo (path);

        path.set ("file.bar");
        path.absolute("c:/prefix");
        foo(path);

        path.set (r"arf/test");
        foo(path);
        path.absolute("c:/prefix");
        foo(path);

        path.name = "foo";
        foo(path);

        path.suffix = ".d";
        path.name = path.suffix;
        foo(path);

        }
}
