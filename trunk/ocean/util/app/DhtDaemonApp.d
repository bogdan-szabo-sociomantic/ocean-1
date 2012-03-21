/*******************************************************************************

    Utility class to do more common tasks a daemon connecting to a DHT node
    needs to do to start running.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.DhtDaemonApp;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;
public import ocean.util.config.ConfigParser : ConfigParser;
public import ocean.text.Arguments : Arguments;

private import ocean.util.app.LoggedCliApp;
private import ocean.util.app.ext.VersionArgsExt;
private import ocean.util.app.ext.UnittestExt;
private import ocean.util.app.ext.DhtClientExt;



/*******************************************************************************

    Extensible class to do more common tasks a daemon connecting to a DHT node
    needs to do to start running.

    This is a subclass of LoggedCliApp, which have the ArgumentsExt, ConfigExt
    and LogExt registered. This class also registers these extra extensions:
    VersionArgsExt, UnittestExt and DhtClientExt.

    So, for using this class you should usually need to implement the run()
    method and any other hook methods provided by the registered extensions.

    Example:

    ---

    import ocean.util.app.DhtDaemonApp;
    import ocean.util.app.ext.VersionInfo;
    import ocean.io.Stdout;
    import tango.util.log.Log;
    import tango.text.convert.Integer;

    class Returner : DhtDaemonApp
    {
        int r;
        this ( )
        {
            super("returner", "Returns an arbitrary error code to the OS",
                    new VersionInfo, "{0} [OPTIONS]",
                    "This program is a simple test for the DhtDaemonApp "
                    "class, and this is a sample help text");
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
            Log.lookup("test").info("Exiting with code {}", this.r);
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

abstract class DhtDaemonApp : LoggedCliApp
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

        Unittest extension.

    ***************************************************************************/

    public UnittestExt utest_ext;


    /***************************************************************************

        DHT client extension.

    ***************************************************************************/

    public DhtClientExt dht_ext;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            ver = application's version information
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it
            default_source_file = default source xml file name
            use_insert_appender = true if the insert appender should be used
                                  instead of the regular one
            omit_unittest = if true, omit unittest run
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, defaults to the global
                     instance provided by the ocean.util.Config module.

    ***************************************************************************/

    this ( char[] name, char[] desc, VersionInfo ver,
            char[] usage = null, char[] help = null,
            char[] default_source_file = "etc/dhtmemory.xml",
            bool use_insert_appender = false,
            bool omit_unittest = false,
            bool loose_config_parsing = false,
            char[][] default_configs = [ "etc/config.ini" ],
            ConfigParser config = null )
    {
        super(name, desc, usage, help, use_insert_appender,
                loose_config_parsing, default_configs, config);

        this.ver_ext = new VersionArgsExt(ver);
        this.ver = this.ver_ext.ver;
        this.args_ext.registerExtension(this.ver_ext);
        this.log_ext.registerExtension(this.ver_ext);
        this.registerExtension(this.ver_ext);

        this.dht_ext = new DhtClientExt(default_source_file);
        this.args_ext.registerExtension(this.dht_ext);

        this.utest_ext = new UnittestExt(omit_unittest);
        this.args_ext.registerExtension(this.utest_ext);
        this.registerExtension(this.utest_ext);
    }

}

