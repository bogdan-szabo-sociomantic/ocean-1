/*******************************************************************************

    Extension for the LogExt ConfigExt extension.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.model.ILogExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.model.IApplication;
public import ocean.util.config.ConfigParser : ConfigParser;

private import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the LogExt extension.

*******************************************************************************/

interface ILogExtExtension : IExtension
{

    /***************************************************************************

        Function executed before the loggers are configured.

        Params:
            app = application instance
            config = configuration parser
            loose_config_parsing = true if errors shouldn't be triggered on
                                   unknown configuration options
            use_insert_appender = true if the insert appender should be used
                                  instead of the regular one

    ***************************************************************************/

    void preConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender );


    /***************************************************************************

        Function executed after the loggers are configured.

        Params:
            app = application instance
            config = configuration parser
            loose_config_parsing = true if errors shouldn't be triggered on
                                   unknown configuration options
            use_insert_appender = true if the insert appender should be used
                                  instead of the regular one

    ***************************************************************************/

    void postConfigureLoggers ( IApplication app, ConfigParser config,
            bool loose_config_parsing, bool use_insert_appender );

}
