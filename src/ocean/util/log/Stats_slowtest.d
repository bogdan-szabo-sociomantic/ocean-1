/*******************************************************************************

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Test-suite for ocean.util.log.Stats.

*******************************************************************************/

module ocean.util.log.Stats_slowtest;

private import ocean.core.Test,
               ocean.util.log.Stats;

private import tango.io.device.TempFile;

unittest
{
    class MyStatsLog : StatsLog
    {
        this ( Config config ) { super(config); }

        void test()
        {
            .test!("==")(this.layout[], `x:10`);
        }
    }

    class Stats
    {
        int x;
    }

    scope temp_file = new TempFile;

    auto logger = new MyStatsLog(new IStatsLog.Config(
        temp_file.toString(),
        IStatsLog.default_max_file_size,
        IStatsLog.default_file_count));

    auto stats = new Stats();
    stats.x = 10;

    logger.add(stats);
    logger.test();
}
