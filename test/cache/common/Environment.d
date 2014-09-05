/******************************************************************************

    Common objects / utilities needed to emulate application environment
    
    Copyright: Copyright (c) 2014 sociomantic labs. All rights reserved
    
*******************************************************************************/

module test.cache.common.Environment; 

/******************************************************************************

    Imports

******************************************************************************/

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.client.TimerEvent;

private import tango.stdc.posix.time;

/******************************************************************************

    Shared event loop

******************************************************************************/

const EpollSelectDispatcher epoll;

/******************************************************************************

    Used instead of "sleep" to keep event loop running

    Params:
        seconds = amount of seconds to wait

******************************************************************************/

void wait(long seconds)
{
    auto timer = new TimerEvent(
        () {
            epoll.shutdown();
            return false;
        }
    );

    timer.set( timespec(seconds) );
    epoll.register(timer); 
    epoll.eventLoop();
}

/******************************************************************************

    Initializes global state

******************************************************************************/

static this()
{
    epoll = new EpollSelectDispatcher();
}
