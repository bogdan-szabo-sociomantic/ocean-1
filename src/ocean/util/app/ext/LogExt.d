/*******************************************************************************

    Application extension to parse configuration files for the logging system.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.LogExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.TypeConvert;

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.Application;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.ConfigExt;

import ocean.util.app.ext.ReopenableFilesExt;

import ocean.util.config.ConfigParser;
import LogUtil = ocean.util.log.Config;
import ClassFiller = ocean.util.config.ClassFiller;

import tango.io.device.File;

import tango.util.log.Log;
import tango.util.log.AppendSyslog;



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

        True if the InsertConsole appender should be used instead of the regular
        one. The InsertConsole appender is needed when using the AppStatus
        module.

    ***************************************************************************/

    public bool use_insert_appender;


    /***************************************************************************

        Constructor.

        Params:
            use_insert_appender = true if the InsertConsole appender should be
                                  used (needed when using the AppStatus module)

    ***************************************************************************/

    this ( bool use_insert_appender = false )
    {
        this.use_insert_appender = use_insert_appender;
    }


    /***************************************************************************

        Extension order. This extension uses -1_000 because it should be
        called early, but after the ConfigExt extension.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -1_000;
    }


    /***************************************************************************

        Parse the configuration file options to set up the loggers.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public void processConfig ( IApplication app, ConfigParser config )
    {
        auto conf_ext = (cast(Application)app).getExtension!(ConfigExt);

        foreach (ext; this.extensions)
        {
            ext.preConfigureLoggers(app, config, conf_ext.loose_config_parsing,
                    this.use_insert_appender);
        }

        auto log_config = ClassFiller.iterate!(LogUtil.Config)("LOG");
        auto log_meta_config = ClassFiller.fill!(LogUtil.MetaConfig)("LOG");

        Appender appender ( char[] file, LogUtil.Layout layout )
        {
            auto reopenable_files_ext =
                (cast(Application)app).getExtension!(ReopenableFilesExt);

            if ( reopenable_files_ext )
            {
                auto stream = new File(file, File.WriteAppending);
                reopenable_files_ext.register(stream);

                return new AppendStream(stream, true, layout);
            }
            else
            {
                auto file_count = castFrom!(size_t).to!(uint)(log_meta_config.file_count);
                return new AppendSyslog(file, file_count,
                    log_meta_config.max_file_size, "gzip {}", "gz",
                    log_meta_config.start_compress, layout);
            }
        }

        LogUtil.configureLoggers(log_config, log_meta_config, &appender,
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

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }


    /***************************************************************************

        Function to filter the list of configuration files to parse.
        Only present to satisfy the interface

        Params:
            app = the application instance
            config = configuration instance
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    public char[][] filterConfigFiles ( IApplication app,
            ConfigParser config, char[][] files )
    {
        // Unused
        return files;
    }
}

