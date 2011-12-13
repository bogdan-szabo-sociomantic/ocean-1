/*******************************************************************************

    Application extension to run unittests at the start of the program.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.UnittestExt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.app.Application;
private import ocean.util.app.model.IApplicationExtension;
private import ocean.util.app.ext.ArgumentsExt;
private import ocean.util.app.ext.model.IArgumentsExtExtension;

private import ocean.text.Arguments;
private import ocean.util.Unittest;



/*******************************************************************************

    Application extension to run unittests at the start of the program.

    This extension is an Application extension and optionally an ArgumentsExt.

    If it's registered as an ArgumentsExt, it adds the option --omit-unittest
    to avoid running the unittests unless omit_unittest is true already).

*******************************************************************************/

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

    public override int order ( )
    {
        return -1_000_000;
    }


    /***************************************************************************

        Adds the command line option --omit-unittest if appropriate.

    ***************************************************************************/

    public override void setupArgs ( Application app, Arguments args )
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

    protected override void preRun ( Application app, char[][] cl_args )
    {
        auto args_ext = app.getExtension!(ArgumentsExt);
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

    public override void postRun ( Application app, char[][] args, int status )
    {
        // Unused
    }

    public override void atExit ( Application app, char[][] args, int status,
            ExitException exception )
    {
        // Unused
    }

    public override ExitException onExitException ( Application app,
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

    public override char[] validateArgs ( Application app, Arguments args )
    {
        // Unused
        return null;
    }

    public override void processArgs ( Application app, Arguments args )
    {
        // Unused
    }

}

