/*******************************************************************************

    Application extension to log or output the version information.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.VersionArgsExt;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.ext.VersionInfo;

import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.ext.model.IArgumentsExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.LogExt;
import ocean.util.app.ext.ConfigExt;
import ocean.util.app.Application;

import ocean.text.Arguments;
import ocean.util.config.ConfigParser;
import ocean.io.Stdout;

import tango.util.log.Log;
import tango.util.log.AppendFile;
import tango.util.log.LayoutDate;



/*******************************************************************************

    Application extension to log or output the version information.

    This extension is an ArgumentsExt and a LogExt extension, being optional for
    both (but makes no sense unless it's registered at least as one of them).

    If it's registered as an ArgumentsExt, it adds the option --version to print
    the version information and exit.

    If it's registered as a LogExt, it will log the version information using
    the logger with the name of this module.

*******************************************************************************/

class VersionArgsExt : IApplicationExtension, IArgumentsExtExtension,
        ILogExtExtension
{

    /***************************************************************************

        Version information.

    ***************************************************************************/

    public VersionInfo ver;


    /***************************************************************************

        True if a default logger for the version should be added.

    ***************************************************************************/

    public bool default_logging;


    /***************************************************************************

        Default name of the file to log when using the default logger.

    ***************************************************************************/

    public char[] default_file;


    /***************************************************************************

        Logger to use to log the version information.

    ***************************************************************************/

    public Logger ver_log;


    /***************************************************************************

        Constructor.

        Params:
            ver = version information.
            default_logging = true if a default logger for the version should be
                              added
            default_file = default name of the file to log when using the
                           default logger

    ***************************************************************************/

    this ( VersionInfo ver, bool default_logging = true,
            char[] default_file = "log/version.log" )
    {
        this.ver = ver;
        this.default_logging = default_logging;
        this.default_file = default_file;
        this.ver_log = Log.lookup("ocean.util.app.ext.VersionArgsExt");
    }


    /***************************************************************************

        Get a single version string with all the libraries versions.

        Params:
            libs = associative array with the name as the key and the revision
                   as the value

        Returns:
            string with the version information of all libraries

    ***************************************************************************/

    protected char[] getLibsVersionsString ( char[][char[]] libs )
    {
        char[] s;
        foreach (name, rev; libs)
        {
            s ~= " " ~ name ~ ":" ~ rev;
        }
        return s;
    }


    /***************************************************************************

        Get the program's name and full version information as a string.

        Params:
            app_name = program's name
            ver = description of the application's version / revision

        Returns:
            String with the version information

    ***************************************************************************/

    protected char[] getVersionString ( char[] app_name, VersionInfo ver )
    {
        return app_name ~ " version " ~ ver.revision ~ " (compiled by '" ~
                ver.build_author ~ "' on " ~ ver.build_date ~ " with " ~
                ver.dmd_version ~ " using GC:" ~
                ver.gc ~ this.getLibsVersionsString(ver.libraries) ~ ")";
    }


    /***************************************************************************

        Extension order. This extension uses 100_000 because it should be
        called very late.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return 100_000;
    }


    /***************************************************************************

        Adds the command line option --version.

        Params:
            app = the application instance
            args = command-line arguments instance

    ***************************************************************************/

    public void setupArgs ( IApplication app, Arguments args )
    {
        args("version").params(0).help("show version information and exit");
    }


    /***************************************************************************

        Just print the version number and exit if --version is present.

        Params:
            app = the application instance
            args = command-line arguments instance

    ***************************************************************************/

    public void processArgs ( IApplication app, Arguments args )
    {
        if (args.exists("version"))
            this.displayVersion(app);
    }

    /***************************************************************************

        Print the version information to Stdout and exit.

        Params:
            app = the application instance

    ***************************************************************************/

    public void displayVersion ( IApplication app )
    {
        Stdout(getVersionString(app.name, this.ver)).newline;
        app.exit(0);
    }


    /***************************************************************************

        Add the default logger if default_logging is true.

        If the configuration variable is present, it will override the current
        default_logging value. If the value does not exist in the config file,
        the value set in the ctor will be used.

        Note that the logger is explicitly set to output all levels, to avoid
        the situation where the root logger is configured to not output level
        'info'.

        Params:
            app = the application instance
            config = the configuration instance
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    public void postConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender )
    {
        this.ver_log.level = this.ver_log.Level.Info;

        this.default_logging = config.get("VERSION", "default_version_log",
                this.default_logging);

        if (this.default_logging)
        {
            this.ver_log.add(new AppendFile(this.default_file, new LayoutDate));
        }
    }


    /***************************************************************************

        Print the version information to the log if the ConfigExt and LogExt are
        present.

        Params:
            app = the application instance
            args = command-line arguments

    ***************************************************************************/

    public void preRun ( IApplication app, char[][] args )
    {
        auto conf_ext = (cast(Application)app).getExtension!(ConfigExt)();
        if (conf_ext is null)
        {
            return;
        }

        auto log_ext = conf_ext.getExtension!(LogExt)();
        if (log_ext is null)
        {
            return;
        }

        this.ver_log.info(getVersionString(app.name, this.ver));
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


    /***************************************************************************

        Unused IArgumentsExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            args = command-line arguments instance

    ***************************************************************************/

    public char[] validateArgs ( IApplication app, Arguments args )
    {
        // Unused
        return null;
    }


    /***************************************************************************

        Unused ILogExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = the configuration instance
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    public void preConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender )
    {
        // Unused
    }

}

