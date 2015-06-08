/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Application extension which handles signals to the process and calls the
    onSignal() method of all registered extensions (see ISignalExtExtension).
    The extension can handle any number of different signals -- depending solely
    on which signals are specified in the constructor.

    Note: not only must the extension be registered with the application but its
    internal SignalEvent (returned by the event() method) must also be
    registered with an epoll instance! Until the event is registered with epoll
    and the event loop started, the signal handlers will not be called in
    response to signals which have occurred.

*******************************************************************************/

module ocean.util.app.ext.SignalExt;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.app.model.IApplicationExtension;
import ocean.util.app.model.ExtensibleClassMixin;

import ocean.util.app.Application;

import ocean.util.app.ext.model.ISignalExtExtension;

import ocean.io.select.client.SignalEvent;



public class SignalExt : IApplicationExtension
{
    /***************************************************************************

        Adds a list of extensions (this.extensions) and methods to handle them.
        See ExtensibleClassMixin documentation for details.

    ***************************************************************************/

    mixin ExtensibleClassMixin!(ISignalExtExtension);


    /***************************************************************************

        Signal event which is registered with epoll to handle notifications of
        the occurrence of the signal.

    ***************************************************************************/

    private SignalEvent event_;


    /***************************************************************************

        Constructor. Creates the internal signal event, handling the specified
        signals. The event (accessible via the event() method) must be
        registered with epoll.

        The list of signals handled may be extended after construction by
        calling the register() method.

        Params:
            signals = list of signals to handle

        Throws:
            SignalErrnoException if the creation of the SignalEvent fails

    ***************************************************************************/

    public this ( int[] signals )
    {
        this.event_ = new SignalEvent(&this.handleSignal, signals);
    }


    /***************************************************************************

        Adds the specified signal to the set of signals handled by this
        extension.

        Params:
            signal = signal to handle

        Returns:
            this instance for chaining

        Throws:
            SignalErrnoException if the updating of the SignalEvent fails

    ***************************************************************************/

    public typeof(this) register ( int signal )
    {
        this.event_.register(signal);

        return this;
    }


    /***************************************************************************

        SignalEvent getter, for registering with epoll.

        Returns:
            internal SignalEvent member

    ***************************************************************************/

    public SignalEvent event ( )
    {
        return this.event_;
    }


    /***************************************************************************

        Extension order. This extension uses -2_000 because it should be called
        before the LogExt and StatsExt.

        Returns:
            the extension order

    ***************************************************************************/

    public override int order ( )
    {
        return -2_000;
    }


    /***************************************************************************

        Signal handler delegate, called from epoll when a signal has fired. In
        turn notifies all registered extensions about the signal.

        Params:
            siginfo = info about signal which has fired

    ***************************************************************************/

    private void handleSignal ( SignalEvent.SignalInfo siginfo )
    {
        foreach ( ext; this.extensions )
        {
            ext.onSignal(siginfo.ssi_signo);
        }
    }


    /***************************************************************************

        Unused IApplicationExtension methods.

        We just need to provide an "empty" implementation to satisfy the
        interface.

    ***************************************************************************/

    public override void preRun ( IApplication app, istring[] args )
    {
    }

    /// ditto
    public override void postRun ( IApplication app, istring[] args, int status )
    {
    }

    /// ditto
    public override void atExit ( IApplication app, istring[] args, int status,
            ExitException exception )
    {
    }

    /// ditto
    public override ExitException onExitException ( IApplication app, istring[] args,
            ExitException exception )
    {
        return exception;
    }
}
