/*******************************************************************************

    Custom event which can be registered with the EpollSelectDispatcher.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    An instance of this class can be registered with an EpollSelectDispatcher,
    and triggered at will, causing it to be selected in the select loop. When it
    is selected, a user-specified callback (given in the class' constructor) is
    invoked.

    Two versions of the class exist, one which counts the number of calls to
    trigger() before the callback is invoked (and passes the count to the
    callback), and one which does not keep a count.

    Usage example:

    ---

        import ocean.io.select.client.SelectEvent;
        import ocean.io.select.EpollSelectDispatcher;

        // Event handler
        void handler ( )
        {
            // Do something
        }

        auto dispatcher = new EpollSelectDispatcher;
        auto event = new SelectEvent(&handler);

        dispatcher.register(event);

        dispatcher.eventLoop();

        // At this point, any time event.trigger is called, the eventLoop will
        // select the event and invoke its handler callback.

    ---

*******************************************************************************/

module ocean.io.select.client.SelectEvent;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.EventFD;

import ocean.io.select.client.model.ISelectClient;




/*******************************************************************************

    CountingSelectEvent class -- counts and reports the number of times the
    trigger() method was called preivous to the event being fired in epoll and
    the class' handle() method being invoked.

*******************************************************************************/

public abstract class ISelectEvent : IAdvancedSelectClient
{
    /***************************************************************************

        Event file descriptor.

    ***************************************************************************/

    private const EventFD event_fd;


    /***************************************************************************

        Constructor. Creates a custom event and hooks it up to the provided
        event handler.

    ***************************************************************************/

    public this ( )
    {
        this.event_fd = new EventFD;
    }


    /***************************************************************************

        Returs:
            the epoll events to register for.

    ***************************************************************************/

    Event events ( )
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
        return this.event_fd.fileHandle;
    }

    /***************************************************************************

        Called from the select dispatcher when the event fires. Calls the
        abstract handle_() method.

        Params:
            event = select event which fired, must be Read

        Returns:
            forwards return value of the abstract handle_() method -- false
            indicates that the event should be unregistered with the selector,
            true indicates that it should remain registered and able to fire
            again

    ***************************************************************************/

    public bool handle ( Event event )
    in
    {
        assert (event == event.EPOLLIN);

        assert(this.handler !is null);
    }
    body
    {
        auto n = this.event_fd.handle();
        assert(n > 0);

        return this.handle_(n);
    }


    /***************************************************************************

        Called from handle() when the event fires.

        Params:
            n = number of times the event was triggered since the last time
                handle() was called by the select dispatcher

        Returns:
            false indicates that the event should be unregistered with the
            selector, true indicates that it should remain registered and able
            to fire again

    ***************************************************************************/

    protected abstract bool handle_ ( ulong n );


    /***************************************************************************

        Triggers the event.

    ***************************************************************************/

    public void trigger ( )
    {
        this.event_fd.trigger();
    }
}



/*******************************************************************************

    SelectEvent class -- calls the user-provided callback (passed to the
    constructor) when the event is fired from epoll. The trigger() method causes
    the event to fire.

*******************************************************************************/

public class SelectEvent : ISelectEvent
{
    /***************************************************************************

        Alias for event handler delegate. The return value indicates whether the
        event should remain registered with the epoll selector, or be
        unregistered after handling.

    ***************************************************************************/

    public alias bool delegate ( ) Handler;


    /***************************************************************************

        Event handler delegate.

    ***************************************************************************/

    private const Handler handler;


    /***************************************************************************

        Constructor.

        Params:
            handler = event handler

    ***************************************************************************/

    public this ( Handler handler )
    {
        this.handler = handler;

        super();
    }


    /***************************************************************************

        Called from handle() when the event fires.

        Params:
            n = number of times the event was triggered since the last time
                handle() was called by the select dispatcher (ignored)

        Returns:
            forwards return value of event handler -- false indicates that the
            event should be unregistered with the selector, true indicates that
            it should remain registered and able to fire again

    ***************************************************************************/

    protected bool handle_ ( ulong n )
    {
        return this.handler();
    }
}



/*******************************************************************************

    CountingSelectEvent class -- calls the user-provided callback (passed to the
    constructor) when the event is fired from epoll. The trigger() method causes
    the event to fire. The number of calls to trigger() which occurred before
    the event fires is counted and passed to the callback.

*******************************************************************************/

public class CountingSelectEvent : ISelectEvent
{
    /***************************************************************************

        Alias for event handler delegate. The return value indicates whether the
        event should remain registered with the epoll selector, or be
        unregistered after handling.

        The ulong passed to the delegate is the number of times the event has
        been triggered since the last time handle() was called from epoll.

    ***************************************************************************/

    public alias bool delegate ( ulong n ) Handler;


    /***************************************************************************

        Event handler delegate.

    ***************************************************************************/

    private const Handler handler;


    /***************************************************************************

        Constructor.

        Params:
            handler = event handler

    ***************************************************************************/

    public this ( Handler handler )
    {
        this.handler = handler;

        super();
    }


    /***************************************************************************

        Called from handle() when the event fires.

        Params:
            n = number of times the event was triggered since the last time
                handle() was called by the select dispatcher

        Returns:
            forwards return value of event handler -- false indicates that the
            event should be unregistered with the selector, true indicates that
            it should remain registered and able to fire again

    ***************************************************************************/

    protected bool handle_ ( ulong n )
    {
        return this.handler(n);
    }
}

