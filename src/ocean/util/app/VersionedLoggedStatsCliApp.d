/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    authors:        Mathias Baumann

    Application class that provides:
    * Version support
    * Stats logging
    * Auto-configuration of tango based loggers
    * Reading of config file
    * Command line parsing

*******************************************************************************/

deprecated module ocean.util.app.VersionedLoggedStatsCliApp;

/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;
public import ocean.util.config.ConfigParser : ConfigParser;
public import ocean.text.Arguments : Arguments;

import ocean.transition;
import ocean.util.app.VersionedLoggedCliApp;
import ocean.util.app.ext.VersionArgsExt;
import ocean.util.app.ext.StatsExt;



deprecated("All applications should be migrated to use either DaemonApp or "
           "CliApp")
abstract class VersionedLoggedStatsCliApp : VersionedLoggedCliApp
{
    /***************************************************************************

        Stats log extension

    ***************************************************************************/

    public StatsExt stats_ext;

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
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, defaults to the global
                     instance provided by the ocean.util.Config module.

    ***************************************************************************/

    this ( istring name, istring desc, VersionInfo ver,
           istring usage = null, istring help = null,
           bool use_insert_appender = false,
           bool loose_config_parsing = false,
           istring[] default_configs = [ "etc/config.ini" ],
           ConfigParser config = null )
    {
        super(name, desc, ver, usage, help, use_insert_appender,
              loose_config_parsing, default_configs, config);

        this.stats_ext = new StatsExt();
        this.config_ext.registerExtension(this.stats_ext);
    }
}
