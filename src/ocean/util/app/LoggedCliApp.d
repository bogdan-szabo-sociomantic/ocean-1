/*******************************************************************************

    Utility class to do more common tasks a command line application with
    a configuration file with loggers have to do to start running.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

deprecated module ocean.util.app.LoggedCliApp;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;
public import ocean.util.config.ConfigParser : ConfigParser;
public import ocean.text.Arguments : Arguments;

import ocean.util.app.ConfiguredCliApp;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.LogExt;
import ocean.util.app.ExitException;

import ocean.transition;
import ocean.util.log.Log;



/*******************************************************************************

    Extensible class to do all the common task needed to run a command line
    application that uses configuration files with loggers.

    This is a subclass of ConfiguredCliApp, it registers an LogExt extension to
    it, it implements the ILogExtExtension interface, and adds itself as an
    LogExt extension.

    So, for using this class you should usually need to implement the run()
    method and the preConfigureLoggers() and postConfigureLoggers() methods if
    you want to customize it.

    Example:

    ---

    import ocean.util.app.LoggedCliApp;
    import ocean.io.Stdout;
    import ocean.util.log.Log;
    import ocean.text.convert.Integer_tango;

    class Returner : LoggedCliApp
    {
        int r;
        this ( )
        {
            super("returner", "Returns an arbitrary error code to the OS",
                    "{0} [OPTIONS]", "This program is a simple test for the "
                    "LoggedCliApp class, and this is a sample help text");
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
        public override void processConfig( IApplication app, ConfigParser config )
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

    int main(istring[] args)
    {
        auto app = new Returner;
        return app.main(args);
    }

    ---

*******************************************************************************/

deprecated("All applications should be migrated to use either DaemonApp or "
           "CliApp")
abstract class LoggedCliApp : ConfiguredCliApp, ILogExtExtension
{

    /***************************************************************************

        Logging extension instance.

    ***************************************************************************/

    public LogExt log_ext;


    /***************************************************************************

        Constructor.

        This constructor only setup the internal state of the class, but does
        not call any extension or user code. The application runs only when the
        main() method is called.

        Params:
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, defaults to the global
                     instance provided by the ocean.util.Config module.

    ***************************************************************************/

    this ( istring name, istring desc, istring usage = null, istring help = null,
           bool use_insert_appender = false, bool loose_config_parsing = false,
           istring[] default_configs = [ "etc/config.ini" ],
           ConfigParser config = null )
    {
        super(name, desc, usage, help, loose_config_parsing, default_configs,
                config);
        this.log_ext = new LogExt(use_insert_appender);
        this.config_ext.registerExtension(this.log_ext);
    }

    /***************************************************************************

        Exit cleanly from the application.

        Calling exit() will properly unwind the stack and all the destructors
        will be called. Should be used only from the main application thread
        though.

        If will also log the message (as a fatal message) if a looger is
        specified.

        Params:
            status = status code to return to the OS
            msg = optional message to show just before exiting
            logger = logger to use to log the message

    ***************************************************************************/

    public void exit(int status, istring msg, Logger logger)
    {
        if (logger !is null)
        {
            logger.fatal(msg);
        }
        throw new ExitException(status, msg);
    }

    /// ditto
    override public void exit(int status, istring msg = null)
    {
        this.exit(status, msg, null);
    }


    /***************************************************************************

        ILogExtExtension methods dummy implementation.

        This methods are implemented with "empty" implementation to ease
        deriving from this class.

        See IConfigExtExtension documentation for more information on how to
        override this methods.

    ***************************************************************************/

    public override void preConfigureLoggers ( IApplication app,
            ConfigParser config, bool loose_config_parsing,
            bool use_insert_appender )
    {
        // Dummy implementation of the interface
    }

    public override void postConfigureLoggers ( IApplication app,
            ConfigParser config, bool loose_config_parsing,
            bool use_insert_appender )
    {
        // Dummy implementation of the interface
    }

}
