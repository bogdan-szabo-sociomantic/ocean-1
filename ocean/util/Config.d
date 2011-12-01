/*******************************************************************************

    Provides a global config instance

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        December 2011: Creation

    authors:        Mathias Baumann

    Note that the instance should be filled before usage, 
    using the .parse function

*******************************************************************************/

module ocean.util.Config;


/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.util.config.ConfigParser;


/*******************************************************************************

    Global Config instance

*******************************************************************************/

const ConfigParser Config;


/*******************************************************************************

    Creates the global config instances

*******************************************************************************/

static this ( )
{
    Config = new ConfigParser();
}