/*******************************************************************************

    Application extension to parse configuration for the stats output.

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.util.app.ext.StatsExt;



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
import ocean.util.log.Stats;
import ClassFiller = ocean.util.config.ClassFiller;

import ocean.transition;
import ocean.io.device.File;

import ocean.util.log.Log;
import ocean.util.log.AppendSyslog;



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

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -500;
    }


    /***************************************************************************

        Parse the configuration file options to set up the stats log.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void processConfig ( IApplication app, ConfigParser config )
    {
        this.stats_log = this.newStatsLog(app,
            ClassFiller.fill!(StatsLog.Config)("STATS", config));
    }


    /***************************************************************************

        Creates a new stats log instance according to the provided config
        settings. If the reopenable files extension exists, the log file is
        registered with it.

        Params:
            app = the application instance
            stats_config = stats log configuration instance

        Returns:
            new, configured StatsLog instance

    ***************************************************************************/

    static public StatsLog newStatsLog ( IApplication app,
        StatsLog.Config stats_config )
    {
        Appender newAppender ( istring file, Appender.Layout layout )
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
                auto file_count = castFrom!(size_t).to!(uint)(stats_config.file_count);
                return new AppendSyslog(file, file_count,
                    stats_config.max_file_size, "gzip {}", "gz",
                    stats_config.start_compress, layout);
            }
        }

        return new StatsLog(stats_config, &newAppender);
    }


    /***************************************************************************

        Unused IConfigExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = configuration instance

    ***************************************************************************/

    public override void preParseConfig ( IApplication app, ConfigParser config )
    {
        // Unused
    }


    /***************************************************************************

        Unused IConfigExtExtension method.

        We just need to provide an "empty" implementation to satisfy the
        interface.

        Params:
            app = the application instance
            config = configuration instance
            files = current list of configuration files to parse

        Returns:
            new list of configuration files to parse

    ***************************************************************************/

    public override istring[] filterConfigFiles ( IApplication app,
                                         ConfigParser config,
                                         istring[] files )
    {
        // Unused
        return files;
    }
}
