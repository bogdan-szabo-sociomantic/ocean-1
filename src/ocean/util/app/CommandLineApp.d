/*******************************************************************************

    Utility class to do more common tasks a command line application have to do
    to start running (parsing command line arguments).

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.CommandLineApp;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application;
public import ocean.text.Arguments : Arguments;

import ocean.util.app.ext.ArgumentsExt;
import ocean.util.app.ext.model.IArgumentsExtExtension;



/*******************************************************************************

    Extensible class to do all the common task needed for a command line
    application to run.

    This is a subclass of Application, it registers an ArgumentsExt extension to
    it, it implements the IArgumentsExtExtension interface, and adds itself as
    an ArgumentsExt extension.

    It also implements the Application.run() calling a new abstract run()
    method, which passes the Arguments instance instead of the raw array of
    string command line arguments.

    So, for using this class you should usually need to implement the new
    run(Arguments args) method and the setupArgs(), validateArgs() and
    processArgs() methods if you want to use custom command line options.

    Example:

    ---

    import ocean.util.app.CommandLineApp;
    import ocean.io.Stdout;
    import tango.text.convert.Integer;

    class Returner : CommandLineApp
    {
        int r;
        this ( )
        {
            super("returner", "Returns an arbitrary error code to the OS",
                    "{0} [OPTIONS]", "This program is a simple test for the "
                    "CommandLineApp class, and this is a sample help text");
        }
        public override void setupArgs( IApplication app, Arguments args )
        {
            args("return").aliased('r').params(1).smush().defaults("0")
                .help("code to return to the OS");
        }
        public override cstring validateArgs( IApplication app, Arguments args )
        {
            if (toInt(args("return").assigned[0]) < 0)
            {
                return "--return should be a positive integer";
            }
            return null;
        }
        public override void processArgs( IApplication app, Arguments args )
        {
            this.r = toInt(args("return").assigned[0]);
        }
        protected override int run ( Arguments args )
        {
            return this.r;
        }

    }

    int main(istring[] args)
    {
        auto app = new Returner;
        return app.main(args);
    }

    ---

*******************************************************************************/

abstract class CommandLineApp : Application, IArgumentsExtExtension
{

    /***************************************************************************

        Command line arguments used by the application.

    ***************************************************************************/

    public Arguments args;


    /***************************************************************************

        Command line arguments extension used by the application.

    ***************************************************************************/

    public ArgumentsExt args_ext;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        See ocean.text.Arguments for details on format of the parameters.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it

    ***************************************************************************/

    public this ( istring name, istring desc,
            istring usage = null, istring help = null )
    {
        super(name, desc);
        this.args_ext = new ArgumentsExt(name, desc, usage, help);
        this.args = this.args_ext.args;
        this.args_ext.registerExtension(this);
        this.registerExtension(this.args_ext);
    }


    /***************************************************************************

        Run implementation that forwards to run(Arguments args).

        You shouldn't override this method anymore, unless you're doing
        something really special, in which case there is probably no point on
        using this class.

    ***************************************************************************/

    protected override int run ( istring[] args )
    {
        return this.run(this.args);
    }


    /***************************************************************************

        Do the actual application work.

        This method is meant to be implemented by subclasses to do the actual
        application work.

        Params:
            args = Command line arguments as an Arguments instence

        Returns:
            status code to return to the OS

    ***************************************************************************/

    protected abstract int run ( Arguments args );


    /***************************************************************************

        IArgumentsExtExtension methods dummy implementation.

        This methods are implemented with "empty" implementation to ease
        deriving from this class.

        See IArgumentsExtExtension documentation for more information on how to
        override this methods.

    ***************************************************************************/

    public void setupArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

    public cstring validateArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
        return null;
    }

    public void processArgs ( IApplication app, Arguments args )
    {
        // Dummy implementation of the interface
    }

}
