/*******************************************************************************

    Posix functions for masking & unmasking signals.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        October 2011: Initial release

    authors:        Gavin Norman

    Masked signals will not be noted but will not fire. If a signal occurs one
    or more times while masked, when it is unmasked it will fire immediately.
    Signals are not queued, so if a signal fires multiple times while masked, it
    will only fire once upon unmasking.

    The list of posix signals is defined in tango.stdc.posix.signal

    Build flags:
        -debug=SignalMask: prints debugging information to Trace

*******************************************************************************/

module ocean.sys.SignalMask;



/*******************************************************************************

    Imports

*******************************************************************************/

version ( Posix )
{
    private import tango.stdc.posix.signal;
}
else
{
    static assert(false, "module ocean.sys.SignalMask only supported in posix environments");
}

debug private import ocean.util.log.Trace;



/*******************************************************************************

    Executes the passed delegate with the specified list if signals masked. The
    signals are automatically unmasked again when the delegate returns.

    Params:
        signals = list of signals to mask
        dg = delegate to execute

*******************************************************************************/

public void maskSignals ( int[] signals, void delegate ( ) dg )
{
    auto old_set = maskSignals(signals);
    scope ( exit )
    {
        debug ( SignalMask )
        {
            sigset_t pending;
            sigpending(&pending);
    
            foreach ( signal; signals )
            {
                if ( sigismember(&pending, signal) )
                {
                    Trace.formatln("Signal {} fired while masked", signal);
                }
            }
        }

        setSignalMask(old_set);
    }

    dg();
}


/*******************************************************************************

    Masks the given list of signals in the calling thread.

    Params:
        signals = list of signals to mask

    Returns:
        previous masked signals set (pass to setSignalMask() to restore the
        previous state)

*******************************************************************************/

public sigset_t maskSignals ( int[] signals )
{
    sigset_t set, old_set;

    sigemptyset(&set);

    foreach ( signal; signals )
    {
        sigaddset(&set, signal);
    }

    pthread_sigmask(SIG_BLOCK, &set, &old_set);

    return old_set;
}


/*******************************************************************************

    Sets the signal mask for the calling thread.

    Params:
        set = set of masked signals

*******************************************************************************/

public void setSignalMask ( ref sigset_t set )
{
    pthread_sigmask(SIG_SETMASK, &set, null);
}

