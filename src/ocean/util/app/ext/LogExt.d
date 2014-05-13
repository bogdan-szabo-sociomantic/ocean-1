/*******************************************************************************

    Application extension to parse configuration files for the logging system.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.LogExt;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.app.model.ExtensibleClassMixin;
private import ocean.util.app.Application;
private import ocean.util.app.ext.model.IConfigExtExtension;
private import ocean.util.app.ext.model.ILogExtExtension;
private import ocean.util.app.ext.ConfigExt;

private import ocean.util.config.ConfigParser;
private import LogUtil = ocean.util.log.Config;
private import ClassFiller = ocean.util.config.ClassFiller;

private import tango.util.log.Log;



/*******************************************************************************

    Application extension to parse configuration files for the logging system.

    This extension is an extension itself, providing new hooks via
    ILogExtExtension.

*******************************************************************************/

class LogExt : IConfigExtExtension
{

    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(ILogExtExtension);


    /***************************************************************************

        True if the insert appender should be used instead of the regular one

    ***************************************************************************/

    public bool use_insert_appender;


    /***************************************************************************

        Convenience alias for layouts

    ***************************************************************************/

    private alias Appender.Layout Layout;


    /***************************************************************************

        Layout to use when logging to file

    ***************************************************************************/

    private Layout file_log_layout;


    /***************************************************************************

        Layout to use when logging to console

    ***************************************************************************/

    private Layout console_log_layout;


    /***************************************************************************

        Constructor.

        Params:
            use_insert_appender = true if the insert appender should be used
                                  instead of the regular one
            file_log_layout = layout to use for logging to file, defaults to
                              LayoutDate
            console_log_layout = layout to use for logging to console, defaults
                                 to SimpleLayout

    ***************************************************************************/

    this ( bool use_insert_appender = false,
           Layout file_log_layout = null,
           Layout console_log_layout = null )
    {
        this.use_insert_appender = use_insert_appender;

        this.file_log_layout    = file_log_layout;
        this.console_log_layout = console_log_layout;
    }


    /***************************************************************************

        Extension order. This extension uses -1_000 because it should be
        called early, but after the ConfigExt extension.

    ***************************************************************************/

    public override int order ( )
    {
        return -1_000;
    }


    /***************************************************************************

        Parse the configuration file options to set up the loggers.

    ***************************************************************************/

    public void processConfig ( IApplication app, ConfigParser config )
    {
        auto conf_ext = (cast(Application)app).getExtension!(ConfigExt);

        foreach (ext; this.extensions)
        {
            ext.preConfigureLoggers(app, config, conf_ext.loose_config_parsing,
                    this.use_insert_appender);
        }

        LogUtil.configureLoggers(ClassFiller.iterate!(LogUtil.Config)("LOG"),
                ClassFiller.fill!(LogUtil.MetaConfig)("LOG"),
                conf_ext.loose_config_parsing, this.use_insert_appender,
                this.file_log_layout, this.console_log_layout);

        foreach (ext; this.extensions)
        {
            ext.postConfigureLoggers(app, config, conf_ext.loose_config_parsing,
                    this.use_insert_appender);
        }
    }


    /***************************************************************************

        Unused IConfigExtExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }

    public char[][] filterConfigFiles ( IApplication app,
            ConfigParser config, char[][] files )
    {
        // Unused
        return files;
    }

}

