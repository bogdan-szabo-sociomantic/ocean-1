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
//private import ocean.util.app.model.IApplication;

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

        See ocean.text.Arguments for details on format of the parameters.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it

    ***************************************************************************/

    public this ( char[] name = null, char[] desc = null,
            char[] usage = null, char[] help = null )
    {
        this.args = new Arguments(name, desc, usage, help);
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

    public void preRun ( IApplication app, char[][] cl_args )
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
            args.displayHelp(Stdout);
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
            Stderr.formatln("\nType {} -h for help", app.name);
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

    public void postRun ( IApplication app, char[][] args, int status )
    {
        // Unused
    }

    public void atExit ( IApplication app, char[][] args, int status,
            ExitException exception )
    {
        // Unused
    }

    public ExitException onExitException ( IApplication app,
            char[][] args, ExitException exception )
    {
        // Unused
        return exception;
    }

}

