/*******************************************************************************

    Extension for the ConfigExt Application and ArgumentsExt extension.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    authors:        Leandro Lucarella

*******************************************************************************/

module ocean.util.app.ext.model.IConfigExtExtension;



/*******************************************************************************

    Imports

*******************************************************************************/

public import ocean.util.app.model.IApplication;
public import ocean.util.config.ConfigParser : ConfigParser;

import ocean.util.app.model.IExtension;



/*******************************************************************************

    Interface for extensions for the ConfigExt extension.

*******************************************************************************/

interface IConfigExtExtension : IExtension
{

    /***************************************************************************

        Function executed before the configuration files are parsed.

        Params:
            app = application instance
            config = configuration parser

    ***************************************************************************/

    void preParseConfig ( IApplication app, ConfigParser config );


    /***************************************************************************

        Function to filter the list of configuration files to parse.

        Params:
            app = application instance
            config = configuration parser
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    char[][] filterConfigFiles ( IApplication app, ConfigParser config,
            char[][] files );


    /***************************************************************************

        Function executed after the configuration files are parsed.

        Params:
            app = application instance
            config = configuration parser

    ***************************************************************************/

    void processConfig ( IApplication app, ConfigParser config );

}

