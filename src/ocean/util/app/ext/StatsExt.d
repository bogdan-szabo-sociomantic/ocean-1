/*******************************************************************************

    Application extension to parse configuration for the stats output.

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.util.app.ext.StatsExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.ExtensibleClassMixin;
import ocean.util.app.Application;
import ocean.util.app.ext.model.IConfigExtExtension;
import ocean.util.app.ext.model.ILogExtExtension;
import ocean.util.app.ext.ConfigExt;

import ocean.util.config.ConfigParser;
import ocean.util.log.Stats;
import ClassFiller = ocean.util.config.ClassFiller;

import tango.util.log.Log;



/*******************************************************************************

    Application extension to parse configuration files for the stats output.

*******************************************************************************/

class StatsExt : IConfigExtExtension
{
    /***************************************************************************

        Stats Log instance

    ***************************************************************************/

    public StatsLog stats_log;

    /***************************************************************************

        Extension order. This extension uses -500 because it should be
        called early, but after the LogExt extension.

    ***************************************************************************/

    public override int order ( )
    {
        return -500;
    }


    /***************************************************************************

        Parse the configuration file options to set up the stats log.

    ***************************************************************************/

    public void processConfig ( IApplication app, ConfigParser config )
    {
        this.stats_log = new StatsLog(ClassFiller.fill!(
                                            IStatsLog.Config)("STATS"));
    }


    /***************************************************************************

        Unused IConfigExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }


    /***************************************************************************

        Unused IConfigExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public char[][] filterConfigFiles ( IApplication app,
            ConfigParser config, char[][] files )
    {
        // Unused
        return files;
    }

}

