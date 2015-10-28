/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: May 2004

        author:         Kris

*******************************************************************************/

module tango.util.log.AppendConsole;

import tango.transition;

import  tango.io.Console;

import tango.io.model.IConduit;

import  tango.util.log.Log;

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
