/*******************************************************************************

    Epoll-based event scheduler.

    copyright:  Copyright (c) 2011 sociomantic labs.
                All rights reserved.

    version:    August 2011 : Initial release

    authors:    Gavin Norman

    Requires linking with libebtree:

    ---

        -L-lebtree

    ---

    Usage example:

    ---

        import swarm.core.client.request.scheduler.Scheduler;

        // Struct associated with each event.
        struct EventParams
        {
            int x;
        }

        // Delegate called when an event fired. Receives the associated struct.
        void fired ( ref EventParams p )
        {
            Stdout.formatln("{} fired", p.x);
        }

        // Construct required objects.
        auto epoll = new EpollSelectDispatcher;
        auto scheduler = new EpollScheduler!(Params)(epoll, clock);

        // Schedule some events.
        scheduler.schedule((ref EventParams p){p.x = 0;}, &fired, 2_000_000);
        scheduler.schedule((ref EventParams p){p.x = 1;}, &fired, 4_000_000);
        scheduler.schedule((ref EventParams p){p.x = 2;}, &fired, 6_000_000);

        // Set everything going by starting the epoll event loop.
        Stdout.formatln("Starting eventloop");
        epoll.eventLoop;
        Stdout.formatln("Event loop finished");

    ---

*******************************************************************************/

module ocean.io.select.client.Scheduler;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.util.container.pool.ObjectPool;

import ocean.io.select.EpollSelectDispatcher;

import ocean.io.select.timeout.TimerEventTimeoutManager;

import ocean.time.timeout.model.ITimeoutClient;

import ocean.transition;
debug import ocean.text.convert.Format;




/*******************************************************************************

    Scheduler class template.

    Each event is added to the scheduler along with a data item (see template
    parameters). The data item is stored internally to the scheduler, along with
    the event delegate, as a convenience to the end-user, who thus does not need
    to maintain an external pool of the data items associated with each event.

    Internally, the scheduler works using a timer event, which is registered to
    epoll with the time until the soonest scheduled event. When the last
    scheduled event fires, the timer event is unregistered from epoll.

    Template_Params:
        EventData = type of data to be stored along with each event

    TODO: could probably be adapted to a version which allows simple events
    without attached data, if we need that.

*******************************************************************************/

public class Scheduler ( EventData ) : TimerEventTimeoutManager
{
    /***************************************************************************

        Alias for a delegate which is called when a scheduled event fires.

    ***************************************************************************/

    public alias void delegate ( ref EventData data ) EventFiredDg;


    /***************************************************************************

        Alias for a delegate which is called when a scheduled event is
        registered, allowing the user to setup the required data for the event.

    ***************************************************************************/

    public alias void delegate ( ref EventData data ) EventSetupDg;


    /***************************************************************************

        Internal event class.

    ***************************************************************************/

    private class Event : ITimeoutClient
    {
        /***********************************************************************

            Instance identifier, used by id() method in debug.

        ***********************************************************************/

        debug static int id_num_;

        debug int id_num;


        /***********************************************************************

            Index of this event in the event pool (required by Pool).

        ***********************************************************************/

        public size_t object_pool_index;


        /***********************************************************************

            Data associated with this event.

        ***********************************************************************/

        public EventData data;


        /***********************************************************************

            Delegate to call when this event fires.

        ***********************************************************************/

        public EventFiredDg fired_dg;


        /***********************************************************************

            Registration of this event in the timeout manager.

        ***********************************************************************/

        private ExpiryRegistration expiry_registration;


        /***********************************************************************

            Constructor.

        ***********************************************************************/

        public this ( )
        {
            debug this.id_num = id_num_++;

            this.expiry_registration = new ExpiryRegistration(this);
        }


        /***********************************************************************

            Registers this event to fire in the specified number of
            microseconds.

            Params:
                schedule_us = (minimum) microseconds before event will fire

        ***********************************************************************/

        public void register ( ulong schedule_us )
        {
            this.expiry_registration.register(schedule_us);
        }


        /***********************************************************************

            Unregisters this event.

        ***********************************************************************/

        public void unregister ( )
        {
            this.expiry_registration.unregister();
        }


        /***********************************************************************

            ITimeoutClient interface method. Invoked when the client times out.
            Calls the fired delegate and returns this event to the event pool.

        ***********************************************************************/

        public void timeout ( )
        {
            this.fired_dg(this.data);
            this.outer.events.recycle(this);
        }


        /***********************************************************************

            String identifier for debugging.

        ***********************************************************************/

        debug
        {
            private mstring id_buf;

            protected cstring id ( )
            {
                this.id_buf.length = 0;
                Format.format(this.id_buf, "Scheduler.Event {}", this.id_num);
                return this.id_buf;
            }
        }
    }


    /***************************************************************************

        Epoll select dispatcher used to manage the scheduler. Passed as a
        reference to the constructor.

    ***************************************************************************/

    private EpollSelectDispatcher epoll;


    /***************************************************************************

        Re-usable pool of scheduled events.

    ***************************************************************************/

    private ObjectPool!(Event) events;


    /***************************************************************************

        Constructor.

        Params:
            epoll = epoll select dispatcher to use
            max_events = limit on the number of events which can be managed by
                the scheduler at one time. (0 = no limit)

    ***************************************************************************/

    public this ( EpollSelectDispatcher epoll, uint max_events = 0 )
    {
        this.epoll = epoll;

        this.events = new ObjectPool!(Event);

        if ( max_events )
        {
            this.events.setLimit(max_events);
        }
    }


    /***************************************************************************

        Registers a new event with the scheduler.

        Params:
            setup_dg = delegate called to initialise event's associated data
            fired_dg = delegate called when event fires
            schedule_us = (minimum) microseconds before event will fire

        Throws:
            The pool throws a LimitExceededException if the event pool is full
            and the new event cannot be scheduled.

    ***************************************************************************/

    public void schedule ( EventSetupDg setup_dg, EventFiredDg fired_dg,
        ulong schedule_us )
    in
    {
        assert(setup_dg !is null, typeof(this).stringof ~ ".schedule: event setup delegate is null");
        assert(fired_dg !is null, typeof(this).stringof ~ ".schedule: event fired delegate is null");
    }
    body
    {
        auto event = this.events.get(new Event);
        event.fired_dg = fired_dg;

        setup_dg(event.data);

        if ( schedule_us )
        {
            event.register(schedule_us);
            this.epoll.register(this.select_client);
        }
        else
        {
            event.timeout();
        }
    }


    /***************************************************************************

        Returns:
            number of currently scheduled events

        Note: this method is aliased as 'length'

    ***************************************************************************/

    public size_t scheduled_events ( )
    {
        return this.events.length;
    }

    public alias scheduled_events length;


    /***************************************************************************

        Unregisters all registered events (thus calls stopTimeout()).

    ***************************************************************************/

    public void clear ( )
    {
        scope iterator = this.events.new BusyItemsIterator;
        foreach ( event; iterator )
        {
            event.unregister();
        }
        this.events.clear();
    }

    /***************************************************************************

        Disables the timer event and unregisters it from epoll.

    ***************************************************************************/

    override protected void stopTimeout ( )
    {
        super.stopTimeout();
        this.epoll.unregister(this.select_client);
    }
}

unittest
{
    // create instance to check if it compiles
    class Dummy { }
    Scheduler!(Dummy) scheduler;
}
