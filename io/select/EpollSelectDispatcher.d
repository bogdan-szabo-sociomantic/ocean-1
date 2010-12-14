/******************************************************************************

    Wraps a Tango EpollSelector and manages an I/O event loop with automatic
    handler invocation and unregistration.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

    The SelectDispatcher class wraps a Tango EpollSelector and uses
    ISelectClient instances for Select I/O event registration, unregistration
    and event handler invocation. An I/O event loop is provided that runs while
    there are Select event registrations. This loop automatically invokes the
    registered handlers; via the return value each handler may indicate that it
    wishes to be unregistered. After the ISelectClient instance has been
    unregistered, its finalize() method is invoked.
    If a handler throws an Exception, it is caught, the ISelectClient containing
    that handler is unregistered immediately and finalize() is invoked.
    Exceptions thrown by the ISelectClient's finalize() methods are not caught. 

 ******************************************************************************/

module io.select.EpollSelectDispatcher;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.io.select.SelectDispatcher;
import tango.io.selector.EpollSelector;

/******************************************************************************/

class EpollSelectDispatcher: SelectDispatcher
{
    /**************************************************************************

        Constructor
        
        Params:
            size       = value that provides a hint for the maximum amount of
                         conduits that will be registered
            max_events = value that provides a hint for the maximum amount of
                         conduit events that will be returned in the selection
                         set per call to select.
    
     **************************************************************************/

    this ( uint size = EpollSelector.DefaultSize,
           uint max_events = EpollSelector.DefaultMaxEvents )
    {
        super(new EpollSelector, size, max_events);
    }
}