/*******************************************************************************

    Epoll-based event scheduler.

    Multiplexes multiple, logical timers into a single timer fd (see
    ocean.io.select.client.TimerEvent).

    copyright:  Copyright (c) 2011 sociomantic labs.
                All rights reserved.

*******************************************************************************/

deprecated module ocean.io.select.client.Scheduler;

public import ocean.io.select.client.TimerSet;

deprecated("The Scheduler class has been moved/renamed to ocean.io.select.client.TimerSet")
template Scheduler ( EventData )
{
    alias TimerSet!(EventData) Scheduler;
}

unittest
{
    // create instance to check if it compiles
    class Dummy { }
    Scheduler!(Dummy) timer_set;
}
