/*******************************************************************************

    Custom event for use with fibers and epoll, allowing a process to be
    suspended until the event is triggered.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        August 2011: Initial release

    authors:        Gavin Norman

    Usage example:

    ---

        import ocean.io.select.event.FiberSelectEvent;
        import ocean.io.select.EpollSelectDispatcher;

        auto fiber = new MessageFiber(&coroutine);

        auto epoll = new EpollSelectDispatcher;
        auto event = new FiberSelectEvent(fiber, epoll);

        // Fiber method
        void coroutine ( )
        {
            // Do something.

            // Wait on the event, suspends the fiber.
            event.wait();

            // When event.trigger is called (from elsewhere), the fiber is
            // resumed.
        }

    ---

*******************************************************************************/

module ocean.io.select.event.FiberSelectEvent;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.MessageFiber;

private import ocean.sys.EventFD;

private import ocean.io.select.model.IFiberSelectClient;

debug private import ocean.util.log.Trace;

/*******************************************************************************

    Fiber select event class

*******************************************************************************/

public class FiberSelectEvent : IFiberSelectClient
{
    /***************************************************************************

        Token used when suspending / resuming fiber.

    ***************************************************************************/

    static private MessageFiber.Token EventFired;


    /***************************************************************************

        Static ctor. Initialises fiber token.

    ***************************************************************************/

    static this ( )
    {
        EventFired = MessageFiber.Token("event_fired");
    }


    /***************************************************************************

        Custom event.

    ***************************************************************************/

    private const EventFD event;


    /***************************************************************************

        Constructor.

        Params:
            fiber = fiber to suspend / resume with event wait / trigger

    ***************************************************************************/

    public this ( SelectFiber fiber )
    {
        super(fiber);

        this.event = new EventFD;
    }

    /***************************************************************************

        Returs:
            the epoll events to register for.

    ***************************************************************************/

    public Event events ( )
    {
        return Event.EPOLLIN;
    }

    /***************************************************************************

        Required by ISelectable interface.

        Returns:
            file descriptor used to manage custom event

    ***************************************************************************/

    public Handle fileHandle ( )
    {
        return this.event.fileHandle;
    }


    /***************************************************************************

        Triggers the event.

    ***************************************************************************/

    public void trigger ( )
    {
        this.event.trigger();
    }


    /***************************************************************************

        Suspends the fiber until the event is triggered.

    ***************************************************************************/

    public void wait ( )
    {
        super.fiber.register(this);
        super.fiber.suspend(EventFired, this, fiber.Message(true));
    }


    /***************************************************************************

        Combining trigger() then wait(), this method causes the epoll event loop
        to be resumed, giving other select clients a chance to do something.

    ***************************************************************************/

    public void cede ( )
    {
        this.trigger;
        this.wait;
    }


    /***************************************************************************

        Handles events which occurred for the custom event fd.

        (Implements an abstract super class method.)

        Returns:
            false if the fiber is finished or true if it keeps going

    ***************************************************************************/

    public bool handle ( Event events )
    in
    {
        assert (super.fiber.waiting);
    }
    body
    {
        this.event.handle();

        SelectFiber.Message message = super.fiber.resume(EventFired, this);

        return (message.active == message.active.num)? message.num != 0 : false;
    }
}

