/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: May 2004

        author:         Kris

*******************************************************************************/

module ocean.util.log.AppendConsole;

import ocean.transition;

import ocean.io.Console;

import ocean.io.model.IConduit;

import ocean.util.log.Log;

/*******************************************************************************

        Appender for sending formatted output to the console

*******************************************************************************/

public class AppendConsole : AppendStream
{
    /***********************************************************************

      Create with the given layout

     ***********************************************************************/

    this (Appender.Layout how = null)
    {
        super (Cerr.stream, true, how);
    }

    /***********************************************************************

     Create with the given stream and layout

     ***********************************************************************/

    this ( OutputStream stream, bool flush = false, Appender.Layout how = null )
    {
        super (stream, flush, how);
    }

    /***********************************************************************

      Return the name of this class

     ***********************************************************************/

    override istring name ()
    {
        return this.classinfo.name;
    }
}