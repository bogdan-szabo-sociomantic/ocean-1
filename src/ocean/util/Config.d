/*******************************************************************************

    Provides a global config instance

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        December 2011: Creation

    authors:        Mathias Baumann

    Note that the instance should be filled before usage,
    using the .parseFile function

*******************************************************************************/

module ocean.util.Config;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.config.ConfigParser;


/*******************************************************************************

    Global Config instance

*******************************************************************************/

ConfigParser Config;


/*******************************************************************************

    Creates the global config instances

*******************************************************************************/

static this ( )
{
    Config = new ConfigParser();
}
