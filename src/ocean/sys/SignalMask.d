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
        -debug=SignalMask: prints debugging information to Stderr

*******************************************************************************/

module ocean.sys.SignalMask;


/*******************************************************************************

    Imports

*******************************************************************************/

version ( Posix )
{
    import tango.stdc.posix.signal;
}
else
{
    static assert(false, "module ocean.sys.SignalMask only supported in posix environments");
}

debug ( SignalMask ) import ocean.io.Stdout : Stderr;



/*******************************************************************************

    Signal set struct wrapping the C sigset_t and its setter / getter functions.

    Note that, as this is a struct rather than a class, and thus has no
    constructor, it is necessary to explicitly call the clear() method before
    using an instance.

*******************************************************************************/

public struct SignalSet
{
    /***************************************************************************

        Signal set.

    ***************************************************************************/

    private sigset_t sigset;


    /***************************************************************************

        Clears all signals in the set (i.e. sets to the set of no signals).

    ***************************************************************************/

    public void clear ( )
    {
        sigemptyset(&this.sigset);
    }


    /***************************************************************************

        Sets to the set of all signals.

    ***************************************************************************/

    public void setAll ( )
    {
        sigfillset(&this.sigset);
    }


    /***************************************************************************

        Removes the specified signal from the set.

        Params:
            signal = signal to remove from set

        This method is aliased as opSub.

    ***************************************************************************/

    public void remove ( int signal )
    {
        sigdelset(&this.sigset, signal);
    }

    public alias remove opSub;


    /***************************************************************************

        Adds the specified signal to the set.

        Params:
            signal = signal to add to set

        This method is aliased as opAdd.

    ***************************************************************************/

    public void add ( int signal )
    {
        sigaddset(&this.sigset, signal);
    }

    public alias add opAdd;


    /***************************************************************************

        Removes the specified signals from the set.

        Params:
            signals = signals to remove from set

        This method is aliased as opSub.

    ***************************************************************************/

    public void remove ( int[] signals )
    {
        foreach ( signal; signals )
        {
            this.remove(signal);
        }
    }

    public alias remove opSub;


    /***************************************************************************

        Adds the specified signals to the set.

        Params:
            signals = signals to add to set

        This method is aliased as opAdd.

    ***************************************************************************/

    public void add ( int[] signals )
    {
        foreach ( signal; signals )
        {
            this.add(signal);
        }
    }

    public alias add opAdd;


    /***************************************************************************

        Tells whether a signal is in the set.

        Params:
            signal = signal to test

        Returns:
            true if signal is in set

    ***************************************************************************/

    public bool isSet ( int signal )
    {
        return !!sigismember(&this.sigset, signal);
    }


    /***************************************************************************

        Cast operator for convenient use of this struct in C functions which
        accept a sigset_t.

    ***************************************************************************/

    public sigset_t opCast ( )
    {
        return this.sigset;
    }
}



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
                    Stderr.formatln("Signal {} fired while masked", signal);
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

public SignalSet maskSignals ( int[] signals )
{
    SignalSet set, old_set;

    set.clear;
    set.add(signals);

    pthread_sigmask(SIG_BLOCK, &set.sigset, &old_set.sigset);

    return old_set;
}


/*******************************************************************************

    Gets the signal mask for the calling thread.

    Returns:
        set of currently masked signals for the calling thread

*******************************************************************************/

public SignalSet getSignalMask ( )
{
    SignalSet current_set;

    pthread_sigmask(SIG_BLOCK, null, &current_set.sigset);

    return current_set;
}


/*******************************************************************************

    Sets the signal mask for the calling thread. All signals in the passed set
    will be masked, all other signals will be unmasked.

    Params:
        set = set of signals to mask / unmask

*******************************************************************************/

public void setSignalMask ( SignalSet set )
{
    pthread_sigmask(SIG_SETMASK, &set.sigset, null);
}

