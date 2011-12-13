/*******************************************************************************

    Application extension to parse command line arguments.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.ArgumentsExt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.app.model.ExtensibleClassMixin;
private import ocean.util.app.model.IApplicationExtension;
private import ocean.util.app.ext.model.IArgumentsExtExtension;
private import ocean.util.app.Application;

private import ocean.text.Arguments;
private import ocean.io.Stdout;



/*******************************************************************************

    Application extension to parse command line arguments.

    This extension is an extension itself, providing new hooks via
    IArgumentsExtExtension.

    By default it adds a --help command line argument to show a help message.

*******************************************************************************/

class ArgumentsExt : IApplicationExtension
{

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(IArgumentsExtExtension);


    /***************************************************************************

        Command line arguments parser and storage.

    ***************************************************************************/

    public Arguments args;


    /***************************************************************************

        Constructor.

    ***************************************************************************/

    this ( )
    {
        this.args = new Arguments;
    }


    /***************************************************************************

        Extension order. This extension uses -100_000 because it should be
        called very early.

    ***************************************************************************/

    public override int order ( )
    {
        return -100_000;
    }


    /***************************************************************************

        Setup, parse, validate and process command line args (Application hook).

        This function do all the extension processing invoking all the
        extensions hooks. It also adds the --help option, and if it's present in
        the arguments, shows the help and exits the program.

        If argument parsing or validation fails (including extensions
        validation), it also prints an error message and exits.

    ***************************************************************************/

    public override void preRun ( Application app, char[][] cl_args )
    {
        auto args = this.args;

        args("help").aliased('h').params(0)
            .help("display this help message and exit");

        foreach (ext; this.extensions)
        {
            ext.setupArgs(app, args);
        }

        auto args_ok = args.parse(cl_args[1 .. $]);

        if ( args.exists("help") )
        {
            Stdout.formatln("{}", app.desc);
            args.displayHelp(app.name, Stdout);
            app.exit(0);
        }

        char[][] errors;
        foreach (ext; this.extensions)
        {
            char[] error = ext.validateArgs(app, args);
            if (error != "")
            {
                errors ~= error;
                args_ok = false;
            }
        }

        if (!args_ok)
        {
            Stderr.red;
            args.displayErrors(Stderr);
            foreach (error; errors)
            {
                Stderr(error).newline;
            }
            Stderr.default_colour;
            Stderr.formatln("\nType {} -h for help", cl_args[0]);
            app.exit(2);
        }

        foreach (ext; this.extensions)
        {
            ext.processArgs(app, args);
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

}

