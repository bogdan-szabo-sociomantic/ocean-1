/*******************************************************************************

    Application extension to run unittests at the start of the program.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.UnittestExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.Application;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.ArgumentsExt;
import ocean.util.app.ext.model.IArgumentsExtExtension;

import ocean.text.Arguments;
import ocean.util.Unittest;



/*******************************************************************************

    Application extension to run unittests at the start of the program.

    This extension is an Application extension and optionally an ArgumentsExt.

    If it's registered as an ArgumentsExt, it adds the option --omit-unittest
    to avoid running the unittests unless omit_unittest is true already).

*******************************************************************************/

deprecated
class UnittestExt : IApplicationExtension, IArgumentsExtExtension
{

    /***************************************************************************

        If true, omit unittest run.

    ***************************************************************************/

    bool omit_unittest;


    /***************************************************************************

        Constructor.

        Params:
            omit_unittest = if true, omit unittest run

    ***************************************************************************/

    this ( bool omit_unittest = false )
    {
        this.omit_unittest = omit_unittest;
    }


    /***************************************************************************

        Extension order. This extension uses -1_000_000 because it should be
        called very early, probably before anything else.

    ***************************************************************************/

    deprecated public override int order ( )
    {
        return -1_000_000;
    }


    /***************************************************************************

        Adds the command line option --omit-unittest if appropriate.

    ***************************************************************************/

    deprecated public void setupArgs ( IApplication app, Arguments args )
    {
        if (!this.omit_unittest)
        {
            args("omit-unittest").params(0).help("don't run unit tests");
        }
    }


    /***************************************************************************

        Run unit tests unless omit_unittest is false (or --omit-unittest was
        specified).

    ***************************************************************************/

    protected void preRun ( IApplication app, char[][] cl_args )
    {
        auto args_ext = (cast(Application)app).getExtension!(ArgumentsExt);
        if (args_ext !is null && !this.omit_unittest)
        {
            this.omit_unittest = args_ext.args("omit-unittest").set;
        }

        if (!this.omit_unittest)
        {
            Unittest.check();
        }
    }


    /***************************************************************************

        Unused IApplicationExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    deprecated public void postRun ( IApplication app, char[][] args, int status )
    {
        // Unused
    }

    deprecated public void atExit ( IApplication app, char[][] args, int status,
            ExitException exception )
    {
        // Unused
    }

    deprecated public ExitException onExitException ( IApplication app,
            char[][] args, ExitException exception )
    {
        // Unused
        return exception;
    }


    /***************************************************************************

        Unused IArgumentsExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    deprecated public char[] validateArgs ( IApplication app, Arguments args )
    {
        // Unused
        return null;
    }

    deprecated public void processArgs ( IApplication app, Arguments args )
    {
        // Unused
    }

}

