/*******************************************************************************

    Application extension to parse command line arguments.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.ArgumentsExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IArgumentsExtExtension;

import ocean.text.Arguments;
import ocean.io.Stdout : Stdout, Stderr;

import tango.transition;
import tango.io.stream.Format : FormatOutput;



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

        Formatted output stream to use to print normal messages.

    ***************************************************************************/

    protected FormatOutput!(char) stdout;


    /***************************************************************************

        Formatted output stream to use to print error messages.

    ***************************************************************************/

    protected FormatOutput!(char) stderr;


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
            stdout = Formatted output stream to use to print normal messages
            stderr = Formatted output stream to use to print error messages

    ***************************************************************************/

    public this ( istring name = null, istring desc = null,
            istring usage = null, istring help = null,
            FormatOutput!(char) stdout = Stdout,
            FormatOutput!(char) stderr = Stderr )
    {
        this.stdout = stdout;
        this.stderr = stderr;
        this.args = new Arguments(name, desc, usage, help);
    }


    /***************************************************************************

        Extension order. This extension uses -100_000 because it should be
        called very early.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -100_000;
    }


    /***************************************************************************

        Setup, parse, validate and process command line args (Application hook).

        This function does all the extension processing invoking all the
        extension hooks. It also adds the --help option, which when present,
        shows the help and exits the program.
        If the version argument is present and the version extension is in use,
        the program will exit after displaying the version text.

        If argument parsing or validation fails (including extensions
        validation), it also prints an error message and exits. Note that if
        argument parsing fails, validation is not performed.

        Params:
            app = the application instance
            cl_args = command line arguments

    ***************************************************************************/

    public void preRun ( IApplication app, istring[] cl_args )
    {
        auto args = this.args;

        args("help").aliased('h').params(0)
            .help("display this help message and exit");

        foreach (ext; this.extensions)
        {
            ext.setupArgs(app, args);
        }

        cstring[] errors;
        auto args_ok = args.parse(cl_args[1 .. $]);

        if ( args.exists("help") )
        {
            args.displayHelp(this.stdout);
            app.exit(0);
        }

        if ( args_ok )
        {
            foreach (ext; this.extensions)
            {
                auto error = ext.validateArgs(app, args);
                if (error != "")
                {
                    errors ~= error;
                    args_ok = false;
                }
            }
        }

        if (!args_ok)
        {
            auto ocean_stderr = cast (typeof(Stderr)) this.stderr;
            if (ocean_stderr !is null)
                ocean_stderr.red;
            args.displayErrors(this.stderr);
            foreach (error; errors)
            {
                this.stderr(error).newline;
            }
            if (ocean_stderr !is null)
                ocean_stderr.default_colour;
            this.stderr.formatln("\nType {} -h for help", app.name);
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

    public void postRun ( IApplication app, istring[] args, int status )
    {
        // Unused
    }

    public void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
        // Unused
    }

    public ExitException onExitException ( IApplication app,
            istring[] args, ExitException exception )
    {
        // Unused
        return exception;
    }

}



/*******************************************************************************

    Tests

*******************************************************************************/

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.util.app.Application;
    import ocean.io.device.MemoryDevice;
    import tango.io.stream.Text : TextOutput;
    import tango.core.Array : find;

    class App : Application
    {
        this ( ) { super("app", "A test application"); }
        protected override int run ( istring[] args ) { return 10; }
    }
}


/*******************************************************************************

    Test --help can be used even when required arguments are not specified

*******************************************************************************/

unittest
{

    auto stdout_dev = new MemoryDevice;
    auto stdout = new TextOutput(stdout_dev);

    auto stderr_dev = new MemoryDevice;
    auto stderr = new TextOutput(stderr_dev);

    auto usage_text = "test: usage";
    auto help_text = "test: help";
    auto arg = new ArgumentsExt("test-name", "test-desc", usage_text, help_text,
            stdout, stderr);
    arg.args("--required").params(1).required;

    auto app = new App;

    try
    {
        arg.preRun(app, ["./app", "--help"]);
        test(false, "An ExitException should have been thrown");
    }
    catch (ExitException e)
    {
        // Status should be 0 (success)
        test!("==")(e.status, 0);
        // No errors should be printed
        test!("==")(stderr_dev.bufferSize, 0);
        // Help should be printed to stdout
        auto s = cast(mstring) stdout_dev.peek();
        test(s.length > 0,
                "Stdout should have some help message but it's empty");
        test(s.find(arg.args.desc) < s.length,
             "No application description found in help message:\n" ~ s);
        test(s.find(usage_text) < s.length,
             "No usage text found in help message:\n" ~ s);
        test(s.find(help_text) < s.length,
             "No help text found in help message:\n" ~ s);
        test(s.find("--help") < s.length,
             "--help should be found in help message:\n" ~ s);
    }
}
