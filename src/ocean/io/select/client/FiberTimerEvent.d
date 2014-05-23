/*******************************************************************************

    Copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    Fiber-suspending timer event. Allows a fiber to be suspended for a fixed
    time period.

*******************************************************************************/

module ocean.io.select.client.FiberTimerEvent;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.MessageFiber;

private import ocean.sys.TimerFD;

private import ocean.io.select.client.model.IFiberSelectClient;

private import tango.math.Math : floor;



public class FiberTimerEvent : IFiberSelectClient
{
    /***************************************************************************

        Token used when suspending / resuming fiber.

    ***************************************************************************/

    static private MessageFiber.Token TimerFired;


    /***************************************************************************

        Static ctor. Initialises fiber token.

    ***************************************************************************/

    static this ( )
    {
        TimerFired = MessageFiber.Token("timer_fired");
    }


    /***************************************************************************

        Timer fd.

    ***************************************************************************/

    private const TimerFD timer;


    /***************************************************************************

        Constructor. Initialises (but does not register) the timer fd.

        Params:
            fiber = fiber instance to be suspended/resumed by the timer
            realtime = true:  use a settable system-wide clock.
                       false: use a non-settable clock that is not affected by
                       discontinuous changes in the system clock (e.g., manual
                       changes to system time).

    ***************************************************************************/

    public this ( SelectFiber fiber, bool realtime = false )
    {
        super(fiber);

        this.timer = new TimerFD(realtime);
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
            file descriptor used to manage custom event

    ***************************************************************************/

    public override Handle fileHandle ( )
    {
        return this.timer.fileHandle;
    }


    /***************************************************************************

        Sets the timer to a round number of seconds, registers it, and suspends
        the fiber until it fires.

        Params:
            s = number of seconds to suspend fiber for

    ***************************************************************************/

    public void wait ( uint s )
    {
        this.wait(s, 0);
    }


    /***************************************************************************

        Sets the timer to a number of seconds and milliseconds approximating the
        floating point value specified, registers it, and suspends the fiber
        until it fires.

        Params:
            s = number of seconds to suspend fiber for

    ***************************************************************************/

    public void wait ( double s )
    {
        auto ms = cast(uint)(s - floor(s));
        this.wait(cast(uint)floor(s), ms);
    }


    /***************************************************************************

        Sets the timer to the specified number of seconds and milliseconds,
        registers it, and suspends the fiber until it fires. If both seconds and
        milliseconds are 0, the fiber is not suspended and the event is not
        registered with epoll -- no pause occurs.

        Params:
            s = number of seconds to suspend fiber for
            ms = number of milliseconds to suspend fiber for

    ***************************************************************************/

    private void wait ( uint s, uint ms )
    {
        if ( s == 0 && ms == 0 ) return;

        this.timer.set(s, ms, 0, 0);
        this.fiber.register(this);
        this.fiber.suspend(TimerFired, this, this.fiber.Message(true));
    }


    /***************************************************************************

        Handles events which occurred for the timer event fd. Resumes the fiber.

        (Implements an abstract super class method.)

        Params:
            events = events which occurred for the fd

        Returns:
            false if the fiber is finished or true if it keeps going

    ***************************************************************************/

    public override bool handle ( Event events )
    in
    {
        assert (this.fiber.waiting);
    }
    body
    {
        this.timer.handle();

        SelectFiber.Message message = this.fiber.resume(TimerFired, this);

        // FIXME: this should actually always return false, as we always want
        // the timer to be one-shot. However, as reported in
        // https://github.com/sociomantic/ocean/issues/27
        // there is a fundamental bug with the way the messages are handled. The
        // problem is that IFiberSelectClient.finalize() does not know whether
        // the fiber is still in use (suspended with no client registered) or
        // whether it should be killed. This will need to be revisited and
        // fixed.
        return (message.active == message.active.num)? message.num != 0 : false;
    }
}

