/**
 * A lightweight alternative to core.time that avoids all templates
 * 
 * Copied from Tango-D2 project
 *
 * Copyright: Copyright (C) 2012 Pavel Sountsov.  All rights reserved.
 * License:   BSD style: $(LICENSE)
 * Authors:   Pavel Sountsov
 */
module tango.core.Time;

version(D_Version2)
{
    static import core.time;

    /**
     * Returns a Duration struct that represents secs seconds.
     */
    core.time.Duration seconds(double secs)
    {
            // TODO: check if this can be replaced with plain
            // usage of core.time.Duration

            struct DurationClone
            {
                    long hnsecs;
            }

            return cast(core.time.Duration)(DurationClone(cast(long)(secs * 10_000_000)));
    }
}
else
{
    /**
     * Simply return argument value, needed to avoid version blocks
     * at call site
     */
    double seconds(double secs)
    {
        return secs;
    }
}
