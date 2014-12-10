/*******************************************************************************

    Manages ITimeoutClient instances where each one has an individual timeout
    value. Uses a timer event as timeout notification mechanism.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman, David Eckardt

    Objects that can time out, the so-called timeout clients, must implement
    ITimeoutClient. For each client create an ExpiryRegistration instance and
    pass the object to the ExpiryRegistration constructor.
    Call ExpiryRegistration.register() to set a timeout for the corresponding
    client. The timeout() method of each client is then called when it has
    timed out.
    To disable the timeout for a client that has not timed out yet, call
    ExpiryRegistration.unregister() .

    Initially the object returned by TimerEventTimeoutManager.select_client
    must be registered to an epoll select dispatcher.

    Link with:
        -Llibebtree.a

    Build flags:
        -debug=TimeoutManager = verbose output

*******************************************************************************/

module ocean.io.select.timeout.TimerEventTimeoutManager;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.time.timeout.TimeoutManager;

import ocean.io.select.client.TimerEvent;

import ocean.io.select.client.model.ISelectClient;

import tango.stdc.posix.time: time_t, timespec;

debug
{
    import tango.stdc.time: ctime;
    import tango.io.Stdout;
}

/******************************************************************************/

class TimerEventTimeoutManager : TimeoutManager
{
    /***************************************************************************

        TimerEvent for absolute real-time that calls checkTimeouts() when fired.

    ***************************************************************************/

    private class TimerEvent : ITimerEvent
    {
        /***********************************************************************

            Constructor

        ***********************************************************************/

        this ( )
        {
            super(true); // use real-time
            super.absolute = true; // use absolute time
        }

        /***********************************************************************

            Called when the timer event fires; notifies and unregisters the
            timed out clients.

            Params:
                n = expiration counter (unused, mandatory)

            Returns:
                true to stay registered in the epoll select dispatcher.

        ***********************************************************************/

        protected bool handle_ ( ulong n )
        {
            debug ( TimeoutManager ) Stderr("******** " ~ typeof (this.outer).stringof ~ " expired\n").flush();

            this.outer.checkTimeouts();
            return true;
        }
    }

    /***************************************************************************

        TimerEvent instance

    ***************************************************************************/

    private TimerEvent event;

    /***************************************************************************

        Constructor

    ***************************************************************************/

    public this ( )
    {
        this.event = this.new TimerEvent;
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    protected override void dispose ( )
    {
        delete this.event;
    }

    /***************************************************************************

        Returns:
            the timer event instance to register in an epoll select dispatcher.

    ***************************************************************************/

    public ISelectClient select_client ( )
    {
        return this.event;
    }

    /***************************************************************************

        Enables or changes the timer event time.

        Params:
            next_expiration_us = wall clock time when the next client will time
                                 out as UNIX time in microseconds.

    ***************************************************************************/

    protected override void setTimeout ( ulong next_expiration_us )
    {
        timespec ts = timespec(cast (time_t) (next_expiration_us / 1_000_000),
                               cast (uint)   (next_expiration_us % 1_000_000) * 1000);

        this.event.set(ts);
    }

    /***************************************************************************

        Disables the timer event.

    ***************************************************************************/

    protected override void stopTimeout ( )
    {
        this.event.reset();
    }
}
