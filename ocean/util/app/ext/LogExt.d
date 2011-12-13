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
private import LogUtil = ocean.util.log.Util;
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

        Constructor.

        Params:
            use_insert_appender = true if the insert appender should be used
                                  instead of the regular one

    ***************************************************************************/

    this ( bool use_insert_appender = false )
    {
        this.use_insert_appender = use_insert_appender;
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

    public override void processConfig ( Application app, ConfigParser config )
    {
        auto conf_ext = app.getExtension!(ConfigExt);

        foreach (ext; this.extensions)
        {
            ext.preConfigureLoggers(app, config, conf_ext.loose_config_parsing,
                    this.use_insert_appender);
        }

        LogUtil.configureLoggers(ClassFiller.iterate!(LogUtil.Config)("LOG"),
                ClassFiller.fill!(LogUtil.MetaConfig)("LOG"),
                conf_ext.loose_config_parsing, this.use_insert_appender);

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

    public override void preParseConfig ( Application app, ConfigParser config )
    {
        // Unused
    }

    public override char[][] filterConfigFiles ( Application app,
            ConfigParser config, char[][] files )
    {
        // Unused
        return files;
    }

}

