/*******************************************************************************

    Utility class to do more common tasks a command line application with
    a configuration file have to do to start running.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ConfiguredCliApp;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;
public import ocean.util.config.ConfigParser : ConfigParser;
public import ocean.text.Arguments : Arguments;

private import ocean.util.app.CommandLineApp;
private import ocean.util.app.ext.model.IConfigExtExtension;
private import ocean.util.app.ext.ConfigExt;



/*******************************************************************************

    Extensible class to do all the common task needed to run a command line
    application that uses configuration files.

    This is a subclass of CommandLineApp, it registers an ConfigExt extension to
    it, it implements the IConfigExtExtension interface, and adds itself as an
    ConfigExt extension.

    It also implements the CommandLineApp.run() calling a new abstract run()
    method, which passes command line arguments plus the results of the config
    file parsing.

    So, for using this class you should usually need to implement the new
    run(Arguments args, ConfigParser config) method and the preParseConfig(),
    filterConfigFiles() and processConfig() methods if you want to customize how
    configuration files are parsed and processed.

    Example:

    ---

    import ocean.util.app.ConfiguredCliApp;
    import ocean.io.Stdout;
    import tango.text.convert.Integer;

    class Returner : ConfiguredCliApp
    {
        int r;
        this ( )
        {
            super("returner", "Returns an arbitrary error code to the OS");
        }
        public override void setupArgs( Application app, Arguments args )
        {
            args("return").aliased('r').params(1).smush().defaults("0")
                .help("code to return to the OS");
        }
        public override char[] validateArgs( Application app, Arguments args )
        {
            if (toInt(args("return").assigned[0]) < 0)
            {
                return "--return should be a positive integer";
            }
            return null;
        }
        public override void processConfig( Application app, ConfigParser config )
        {
            this.r = config.get("RETURN", "return_code", 0);
            if (this.args("return").set)
            {
                this.r = toInt(this.args("return").assigned[0]);
            }
        }
        protected override int run ( Arguments args, ConfigParser config )
        {
            return this.r;
        }

    }

    int main(char[][] args)
    {
        auto app = new Returner;
        return app.main(args);
    }

    ---

*******************************************************************************/

abstract class ConfiguredCliApp : CommandLineApp, IConfigExtExtension
{

    /***************************************************************************

        Configuration parser to use to parse the configuration files.

    ***************************************************************************/

    public ConfigParser config;


    /***************************************************************************

        Configuration parsing extension instance.

    ***************************************************************************/

    public ConfigExt config_ext;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        Params:
            name = name of the application
            desc = short description of the application
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, defaults to the global
                     instance provided by the ocean.util.Config module.

    ***************************************************************************/

    this ( char[] name, char[] desc, bool loose_config_parsing = false,
            char[][] default_configs = [ "etc/config.ini" ],
            ConfigParser config = null )
    {
        super(name, desc);
        this.config_ext = new ConfigExt(loose_config_parsing, default_configs,
                config);
        this.config = this.config_ext.config;
        this.config_ext.registerExtension(this);
        this.registerExtension(this.config_ext);
        this.args_ext.registerExtension(this.config_ext);
    }


    /***************************************************************************

        Run implementation that forwards to run(char[][] args, ConfigParser
        config).

        You shouldn't override this method anymore, unless you're doing
        something really special, in which case there is probably no point on
        using this class.

    ***************************************************************************/

    protected override int run ( Arguments args )
    {
        return this.run(args, this.config);
    }


    /***************************************************************************

        Do the actual application work.

        This method is meant to be implemented by subclasses to do the actual
        application work.

        Params:
            args = Command line arguments
            config = parser instance with the parsed configuration

        Returns:
            status code to return to the OS

    ***************************************************************************/

    protected abstract int run ( Arguments args, ConfigParser config );


    /***************************************************************************

        IConfigExtExtension methods dummy implementation.

        This methods are implemented with "empty" implementation to ease
        deriving from this class.

        See IConfigExtExtension documentation for more information on how to
        override this methods.

    ***************************************************************************/

    public override void preParseConfig ( Application app, ConfigParser config )
    {
        // Dummy implementation of the interface
    }

    public override char[][] filterConfigFiles ( Application app,
            ConfigParser config, char[][] files )
    {
        // Dummy implementation of the interface
        if (files.length)
        {
            return files[$-1 .. $];
        }
        return files;
    }

    public override void processConfig ( Application app, ConfigParser config )
    {
        // Dummy implementation of the interface
    }

}

