/*******************************************************************************

    Epoll select dispatcher with per-client timeouts.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Link with:
        -Llibebtree.a

    (The library can be found pre-compiled in ocean.db.ebtree.c.lib, or can be
    built by running 'make' inside ocean.db.ebtree.c.src.)

*******************************************************************************/

module ocean.io.select.TimeoutEpollSelectDispatcher;



/*******************************************************************************

    Imports

******************************************************************************/

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.selector.model.ISelector : Event, SelectionKey;
private import tango.io.model.IConduit: ISelectable;

private import tango.time.Time: TimeSpan;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.timeout.TimeoutManager;

debug private import ocean.util.log.Trace;



/*******************************************************************************

    EpollSelectDispatcher with per client timeout functionality.

******************************************************************************/

deprecated public class TimeoutEpollSelectDispatcher : EpollSelectDispatcher
{
    /***************************************************************************
    
        Timeout manager instance
    
     **************************************************************************/
    
    private TimeoutManager timeout_manager;


    /***************************************************************************
    
        Constructor
    
        Params:
            size       = value that provides a hint for the maximum amount of
                         conduits that will be registered
            max_events = value that provides a hint for the maximum amount of
                         conduit events that will be returned in the selection
                         set per call to select.
    
     **************************************************************************/
    
    this ( uint size       = EpollSelector.DefaultSize,
           uint max_events = EpollSelector.DefaultMaxEvents )
    {
        this.timeout_manager = new TimeoutManager;
    
        super(size, max_events);
    }


    /***************************************************************************
    
        Handles a client for which one or more events fired in epoll. Requests
        the unregistration (without handling) of any event which has timed out.
    
        Params:
            client = client which events fired for
            events = evnts which fired
    
        Returns:
            true to continue, false to unregister the client from epoll
    
     **************************************************************************/
    
    override protected bool handleClient ( ISelectClient client, Event events )
    {
        if ( this.timeout_manager.timedOut(client) )
        {
            return false;
        }
        else
        {
            return super.handleClient(client, events);
        }
    }


    /***************************************************************************
    
        Adds a client registration or overwrites an existing one. Registers the
        client with the timeout manager.
    
        Params:
            client = client to register
    
     **************************************************************************/
    
    override protected void register_ ( ISelectClient client )
    {
        this.timeout_manager.register(client);
    }


    /***************************************************************************
    
        Removes a client registration. Unregisters the client with the timeout
        manager.
    
        Params:
            client = client to unregister
    
     **************************************************************************/
    
    override protected void unregister_ ( ISelectClient client )
    {
        this.timeout_manager.unregister(client);
    }


    /***************************************************************************
    
        While there are clients registered, repeatedly waits for registered
        events to happen, invokes the corresponding event handlers of the
        registered clients and unregisters the clients if they desire so.
    
     **************************************************************************/
    
    override public void eventLoop ( )
    {
        while ( super.selector.count() )
        {
            super.select();
            this.timeout_manager.checkTimeouts();
            super.handleSelectedKeys();
            super.removeUnregisteredClients();
        }
    }


    /***************************************************************************
    
        Returns:
            desired epoll timeout
    
     **************************************************************************/
    
    override protected TimeSpan getTimeout ( )
    {
        return this.timeout_manager.getTimeout();
    }
}

