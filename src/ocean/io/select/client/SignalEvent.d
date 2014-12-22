/*******************************************************************************

    Linux signal file descriptor event for use with epoll.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        December 2011: Initial release

    authors:        Gavin Norman

    Allows signals to be handled as events in epoll, rather than as interrupts.
    One or more signals can be speicified. Once the SignalEvent is registered,
    the default interrupt-based signal handlers will no longer receive these
    events, and they will cause this select client's event to fire in epoll
    instead. When the fired event is handled, a user-provided delegate is
    called, which receives a SignalInfo struct (see ocean.sys.SignalFD)
    providing information about the signal which fired.

    Note that when the SignalEvent is unregistered from epoll, the interrupt-
    based signal handlers are automatically reinstated.

*******************************************************************************/

module ocean.io.select.client.SignalEvent;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.client.model.ISelectClient;

import ocean.sys.SignalFD;




/*******************************************************************************

    Signal select event class.

*******************************************************************************/

public class SignalEvent : ISelectClient
{
    /***************************************************************************

        Alias for signalfd_siginfo.

    ***************************************************************************/

    public alias SignalFD.SignalInfo SignalInfo;


    /***************************************************************************

        Signal event.

    ***************************************************************************/

    private SignalFD event;


    /***************************************************************************

        Signal handler delegate.

    ***************************************************************************/

    private alias void delegate ( SignalInfo siginfo ) Handler;

    private Handler handler;


    /***************************************************************************

        Re-usable array of info about signals which fired.

    ***************************************************************************/

    private SignalInfo[] siginfos;


    /***************************************************************************

        Constructor.

        Params:
            handler = delegate to call when a signal fires (must be non-null)
            signals = list of signals to handle (must be > 0 elements)

    ***************************************************************************/

    public this ( Handler handler, int[] signals ... )
    {
        assert(handler !is null);
        assert(signals.length);

        this.handler = handler;

        this.event = new SignalFD(signals, false);
    }

    /***************************************************************************

        Returs:
            the epoll events to register for.

    ***************************************************************************/

    public override Event events ( )
    {
        return Event.EPOLLIN;
    }


    /***************************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage signal event

    ***************************************************************************/

    public override Handle fileHandle ( )
    {
        return this.event.fileHandle;
    }


    /***************************************************************************

        Checks whether the specified signal is registered to be handled by this
        client.

        Params:
            signal = code of signal to check

        Returns:
            true if the specified signal is handled by this client

    ***************************************************************************/

    public bool isRegistered ( int signal )
    {
        return this.event.isRegistered(signal);
    }


    /***************************************************************************

        Handles events which occurred for the signal event fd.

        (Implements an abstract super class method.)

        Returns:
            always true, to leave event registered with epoll

    ***************************************************************************/

    public override bool handle ( Event events )
    {
        this.event.handle(this.siginfos);

        foreach ( siginfo; this.siginfos )
        {
            this.handler(siginfo);
        }

        return true;
    }


    /***************************************************************************

        Register method, called after this client is registered with the
        SelectDispatcher.

        Masks signals handled by this event, meaning that the default signal
        (interrupt) handler will not deal with them from now.

    ***************************************************************************/

    protected override void registered_ ( )
    {
        this.event.maskHandledSignals();
    }


    /***************************************************************************

        Unregister method, called after this client is unregistered from the
        SelectDispatcher.

        Unmasks signals handled by this event, meaning that the default signal
        (interrupt) handler will deal with them from now.

    ***************************************************************************/

    protected override void unregistered_ ( )
    {
        this.event.unmaskHandledSignals();
    }
}

