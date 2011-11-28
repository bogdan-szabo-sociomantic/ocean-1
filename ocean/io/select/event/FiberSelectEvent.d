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

private import ocean.sys.EventFD;

private import ocean.io.select.model.IFiberSelectClient;

private import tango.io.model.IConduit: ISelectable;

debug private import ocean.util.log.Trace;

/*******************************************************************************

    Fiber select event class

*******************************************************************************/

public class FiberSelectEvent : IFiberSelectClient, ISelectable
{
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
        super(this, fiber);

        this.event = new EventFD;
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

        Returns:
            select events which this class is registered with

    ***************************************************************************/

    public Event events ( )
    {
        return Event.Read;
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
        super.fiber.suspend(fiber.Message(true));
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
            always false, to unregister the event from epoll once it has fired

    ***************************************************************************/

    public bool handle ( Event events )
    in
    {
        assert (super.fiber.waiting);
    }
    body
    {
        this.event.handle();

        super.fiber.resume();

        // TODO: CHECK THIS
        return true; // TODO: was false (see comment)
    }


    /***************************************************************************

        Returns an identifier string for this instance

        (Implements an abstract super class method.)

        Returns:
            identifier string for this instance

    ***************************************************************************/

    debug protected char[] id ( )
    {
        return typeof(this).stringof;
    }
}

