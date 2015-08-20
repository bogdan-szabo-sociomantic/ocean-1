/******************************************************************************

    Keeps the path of a running executable

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

 ******************************************************************************/

module ocean.sys.CmdPath;

/******************************************************************************

    Imports

 ******************************************************************************/

import tango.transition;

import tango.sys.Environment;

import tango.io.FilePath;

import PathUtil = tango.io.Path: normalize;

///
unittest
{
    void main ( istring[] args )
    {
        CmdPath cmdpath;

        // set to path of running executable
        cmdpath.set(args[0]);

        // get absolute directory path of running executable
        auto exepath = cmdpath.get();

        // get absolute path of file "config.ini" located in subdirectory
        // "etc" of the running executable's directory
        auto cfgpath = cmdpath.prepend(["etc", "config.ini"]);
    }
}

/******************************************************************************

    MainExe structure

 ******************************************************************************/

struct CmdPath
{
    /**************************************************************************

         Directory of the executable

     **************************************************************************/

    private istring dir;

    /**************************************************************************

         Sets the executable path.

         Params:
              exepath = executable path

         Returns:
              base directory

     **************************************************************************/

    public istring set ( cstring exepath )
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

    public istring get ( )
    {
        return this.dir;
    }

    /**************************************************************************

        Prepends the absolute base directory to "path" and joins the path.

        Params:
             path = input path

        Returns:
             joined path with prepended absolute base directory

     **************************************************************************/

    public istring prepend ( istring[] path ... )
    {
        return FilePath.join(this.dir ~ path);
    }
}
