/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        5/18/2012: Initial release

    authors:        Leandro Lucarella, Hatem Oraby

    TODO: description of module

*******************************************************************************/

module ocean.util.app.VersionedLoggedCliApp;

/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.Application : Application;
public import ocean.util.config.ConfigParser : ConfigParser;
public import ocean.text.Arguments : Arguments;

private import ocean.util.app.LoggedCliApp;
private import ocean.util.app.ext.VersionArgsExt;



abstract class VersionedLoggedCliApp : LoggedCliApp
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
            name = Name of the application (to show in the help message)
            desc = Short description of what the program does (should be
                         one line only, preferably less than 80 characters)
            ver = application's version information
            usage = How the program is supposed to be invoked
            help = Long description of what the program does and how to use it
            use_insert_appender = true if the insert appender should be used
                                  instead of the regular one
            loose_config_parsing = if true, configuration files will be parsed
                                   in a more relaxed way
            default_configs = default configuration files to parse
            config = configuration parser to use, defaults to the global
                     instance provided by the ocean.util.Config module.

    ***************************************************************************/

    this ( char[] name, char[] desc, VersionInfo ver,
           char[] usage = null, char[] help = null,
           bool use_insert_appender = false,
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
    }

}
