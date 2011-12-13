/*******************************************************************************

    Utility class to do more common tasks a command line application that
    displays version information.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.VersionedCliApp;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;
public import ocean.text.Arguments : Arguments;
public import ocean.util.app.ext.VersionInfo : VersionInfo;

private import ocean.util.app.CommandLineApp;
private import ocean.util.app.ext.VersionArgsExt;



/*******************************************************************************

    Extensible class to do all the common task needed to run a command line
    application that displays version information.

    This is a subclass of CommandLineApp and it registers an VersionArgsExt
    extension to it.

    So, for using this class you should usually need to implement the
    run() and pass the version information.

    Example:

    ---

    import ocean.util.app.VersionedCliApp;

    class Test : VersionedCliApp
    {
        this ( )
        {
            super("test", "Tests --version", new VersionInfo);
        }
        protected override int run ( Arguments args )
        {
            return 0;
        }

    }

    int main(char[][] args)
    {
        auto app = new Test;
        return app.main(args);
    }

    ---

*******************************************************************************/

abstract class VersionedCliApp : CommandLineApp
{

    /***************************************************************************

        Version information.

    ***************************************************************************/

    public VersionInfo ver;


    /***************************************************************************

        Version information extension.

    ***************************************************************************/

    public VersionArgsExt ver_ext;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        Params:
            name = name of the application
            desc = short description of the application
            ver = application's version information

    ***************************************************************************/

    this ( char[] name, char[] desc, VersionInfo ver )
    {
        super(name, desc);
        this.ver_ext = new VersionArgsExt(ver);
        this.ver = this.ver_ext.ver;
        this.args_ext.registerExtension(this.ver_ext);
    }

}

