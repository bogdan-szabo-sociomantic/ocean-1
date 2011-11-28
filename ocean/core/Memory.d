/*******************************************************************************

    Functions dealing with the garbage collector.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        October 2011: Initial release

    authors:        Gavin Norman

    Build flags:
        -version=GCSignalProtection: enables signal masking in the gcSafe()
        function, below

*******************************************************************************/

module ocean.core.Memory;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.sys.SignalMask;

private import tango.stdc.posix.signal;



/*******************************************************************************

    Executes the given delegate with the SIGUSR1 and SIGUSR2 signals masked.
    This is currently necessary for any functions which may call malloc / free,
    which experience deadlocks if interrupted by the garbage collector.

    FIXME: the signal masking is a quick fix, and should really be dealt with in
    the garbage collector by finding a way to not use signals.

    Params:
        dg = delegate to execute

*******************************************************************************/

public void gcSafe ( void delegate ( ) dg )
{
    version ( GCSignalProtection )
    {
        const int[] GC_SIGNALS = [SIGUSR1, SIGUSR2];

        maskSignals(GC_SIGNALS, {
            dg();
        });
    }
    else
    {
        dg();
    }
}

