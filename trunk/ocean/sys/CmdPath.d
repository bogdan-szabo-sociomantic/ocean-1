/******************************************************************************

    Keeps the path of a running executable

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        December 2009: Initial release

    authors:        David Eckardt

    --

    Usage:

        import $(TITLE);

        void main ( char[][] args )
        {
            CmdPath cmdpath;

            // set to path of running executable

            cmdpath(args[0]);

            // get absolute directory path of running executable

            char[] exepath = cmdpath.get();

            // get absolute path of file "config.ini" located in subdirectory
            // "etc" of the running executable's directory

            char[] cfgpath = cmdpath.prepend(["etc", "config.ini"]);
        }

 ******************************************************************************/

module ocean.sys.CmdPath;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.sys.Environment;

private import tango.io.FilePath;

private import PathUtil = tango.io.Path: normalize;

/******************************************************************************

    MainExe structure

 ******************************************************************************/

struct CmdPath
{
    /**************************************************************************

         Directory of the executable

     **************************************************************************/

    private char[] dir;

    /**************************************************************************

         Sets the executable path.

         Params:
              exepath = executable path

         Returns:
              base directory

     **************************************************************************/

    public char[] set ( char[] exepath )
    {
    	scope path = new FilePath(exepath);

        path.set(PathUtil.normalize(path.folder));

        this.dir = path.absolute(Environment.cwd()).toString();

        return this.get();
}

    /**************************************************************************

        Returns the base directory.

        Returns:
             base directory

     **************************************************************************/

    public char[] get ( )
    {
        return this.dir.dup;
    }

    /**************************************************************************

        Prepends the absolute base directory to "path" and joins the path.

        Params:
             path = input path

        Returns:
             joined path with prepended absolute base directory

     **************************************************************************/

    public char[] prepend ( char[][] path ... )
    {
        return FilePath.join(this.dir ~ path);
    }
}
