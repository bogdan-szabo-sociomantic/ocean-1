/*******************************************************************************

    Wraps a Tango AbstractSelector and manages an I/O event loop with automatic
    handler invocation and unregistration.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    The EpollSelectDispatcher class wraps a Tango EpollSelector and uses
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

module ocean.io.select.EpollSelectDispatcher;



/*******************************************************************************

    Imports

 ******************************************************************************/

private import tango.io.selector.EpollSelector;
private import tango.io.selector.model.ISelector : Event, SelectionKey;
private import tango.io.model.IConduit: ISelectable;

private import tango.io.selector.SelectorException : UnregisteredConduitException;

private import tango.core.Exception : SocketException;

private import tango.time.Time: TimeSpan;
private import tango.time.StopWatch;

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.timeout.TimeoutManager;

private import ocean.core.Array : copy;
private import ocean.core.Exception : assertEx;

debug private import tango.util.log.Trace;



/*******************************************************************************

    EpollSelectDispatcher

 ******************************************************************************/

public class EpollSelectDispatcher
{
    alias ISelectClient.Event Event;
    
    /***************************************************************************

        This alias for chainable methods

     **************************************************************************/

    alias typeof (this) This;

    /***************************************************************************

        Wrapped AbstractSelector instance

     **************************************************************************/

    private EpollSelector selector;

    /***************************************************************************

        Re-usable exception

     **************************************************************************/

    private KeyException exception;

    /***************************************************************************

        String buffer used for connection info debug printouts

     **************************************************************************/

    debug (ISelectClient) private char[] connection_info_buffer;

    /***************************************************************************
    
        Re-usable list of clients to be unregistered clients, used by the
        unregisterAfterSelect() method.
    
     **************************************************************************/
    
    private ISelectClient[] clients_to_unregister;

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
        this.selector = new EpollSelector;

        this.exception = new KeyException;
        
        this.selector.open(size, max_events);
    }

    /***************************************************************************

        Opens the selector instance
        
        Note: Since the selector instance is opened automatically at
              instantiation, open() may be called only after close().
    
        Params:
            size     = value that provides a hint for the maximum amount of
                       conduits that will be registered
            max      = value that provides a hint for the maximum amount of
                       conduit events that will be returned in the selection set
                       per call to select.
        Returns:
            this instance
    
     **************************************************************************/
    
    public This open ( uint size       = EpollSelector.DefaultSize,
                       uint max_events = EpollSelector.DefaultMaxEvents )
    {
        this.selector.open(size, max_events);
        
        return this;
    }

    /***************************************************************************

        Closes the selector instance

        Returns:
            this instance

     **************************************************************************/

    public This close ( )
    {
        this.selector.close();
        
        return this;
    }

    /***************************************************************************

        Adds a client registration or overwrites an existing one. Calls the
        protected register_() method, which by default does nothing, but allows
        derived classes to add special client registration behaviour.

        Params:
            client = client to register

        Returns:
            this instance

     **************************************************************************/

    final public This register ( ISelectClient client )
    {
        debug ( ISelectClient ) Trace.formatln("{}: Registering client with epoll", client.id);
        this.selector.register( client.conduit,
                                cast (.Event) (client.events   |
                                               Event.Hangup    |
                                               Event.Error),
                                cast (Object) client);

        this.register_(client);

        return this;
    }

    protected void register_ ( ISelectClient client )
    {
    }
    
   /****************************************************************************

       Removes a client registration. Calls the protected unregister_() method,
       which by default does nothing, but allows derived classes to add special
       client unregistration behaviour.

       Params:
           client = client to unregister

       Returns:
           this instance

        Throws:
            UnregisteredConduitException if the conduit had not been previously
            registered to the selector; SelectorException if there are not
            enough resources to remove the conduit registration.

     **************************************************************************/

    public This unregister ( ISelectClient client )
    {
        this.selector.unregister(client.conduit);

        this.unregister_(client);

        return this;
    }

    protected void unregister_ ( ISelectClient client )
    {
    }

    /**************************************************************************

        Unregisters the chain of io handlers with the select dispatcher. The
        internal data buffer is cleared. An exception is not thrown on
        unregistration error (which may occur if the chain is not registered).

        Params:
            client = client to unregister

        Returns:
            this instance
    
     **************************************************************************/

    public This safeUnregister ( ISelectClient client )
    {
        try
        {
            this.unregister(client);
        }
        catch ( Exception e )
        {
        }

        return this;
    }

    /**************************************************************************

        Requests that the specified client should be unregistered the next time
        an eventLoop cycle ends (ie after the call to epoll_wait and the
        handling of fired events).

        Note that this method should only be used in unusual circumstances. The
        general method of notifying that a client should be unregistered is via
        the return value of its handle() method. It can be used, however, in
        situations where you want to unregister *other* clients from the
        selector during a client's handler. In this case it is unsafe to simply
        call unregister() for the other clients, as this can cause a segfault in
        the foreach loop in handleSelectedKeys().

        Params:
            client = client to unregister

        Returns:
            this instance

     **************************************************************************/

    public This unregisterAfterSelect ( ISelectClient client )
    {
        this.clients_to_unregister ~= client;

        return this;
    }

    /***************************************************************************

        While there are clients registered, repeatedly waits for registered
        events to happen, invokes the corresponding event handlers of the
        registered clients and unregisters the clients if they desire so.

     **************************************************************************/

    public void eventLoop ( )
    {
        while ( this.selector.count() )
        {
            this.select();
            this.handleSelectedKeys();
            this.removeUnregisteredClients();
        }
    }

    /***************************************************************************

        Executes an epoll select.

     **************************************************************************/

    protected void select ( )
    {
        debug ( ISelectClient )
        {
            Trace.formatln("{}.select:", typeof(this).stringof);
            foreach ( key; this.selector )
            {
                auto client = cast(ISelectClient)key.attachment;
                Trace.formatln("   {}: {}", client.id, client.conduit.fileHandle);
            }
        }

        int event_count = this.selector.select(this.getTimeout());
    }

    /***************************************************************************

        Returns:
            desired epoll timeout

     **************************************************************************/

    protected TimeSpan getTimeout ( )
    {
        return TimeSpan.max; // no timeout
    }

    /***************************************************************************

        Calls the handle() method of all selected clients.

     **************************************************************************/

    protected void handleSelectedKeys ( )
    {
        auto selected_keys = this.selector.selectedSet();

        if ( selected_keys ) // EpollSelector.selectedSet() can return null
        {
            foreach ( key; selected_keys )
            {
                bool unregister_key = false;
                
                ISelectClient client = cast (ISelectClient) key.attachment;
                
                Event events = cast (Event) key.events;
                
                debug (ISelectClient)
                {
                    client.connectionInfo(this.connection_info_buffer);
                    Trace.formatln("{}: {}: {:X8}", this.connection_info_buffer, client.id, key.events);
                }

                try
                {
                    unregister_key = !this.handleClient(client, events);
                }
                catch (Exception e)
                {
                    unregister_key = true;
    
                    debug (ISelectClient) Trace.formatln("{}: {}", client.id, e.msg);
    
                    client.error(e, events);
                }
                finally if (unregister_key)
                {
                    this.safeUnregister(client);

                    client.finalize();
                }
            }
        }
    }

    /***************************************************************************

        Handles a client for which one or more events fired in epoll.

        Params:
            client = client which events fired for
            events = evnts which fired

        Returns:
            true to continue, false to unregister the client from epoll

     **************************************************************************/

    protected bool handleClient ( ISelectClient client, Event events )
    {
        return client.handle(this.checkKeyError(events));
    }

    /***************************************************************************

        Unregisters any clients which were requested for removal by the
        unregisterAfterSelect() method.

     **************************************************************************/

    protected void removeUnregisteredClients ( )
    {
        foreach ( client; this.clients_to_unregister )
        {
            this.safeUnregister(client);

            client.finalize();
        }

        this.clients_to_unregister.length = 0;
    }

    /***************************************************************************

        Checks if key is in an erroneous state (ie a Hangup, Error or ReadHangup
        event has occurred).
        
        FIXME: The check for a hangup event must be moved from here to the
               select clients. The reasons are:
               1. The hangup event is not an error on its own and may be
                  expected to happen, e.g. when short term connections are used.
                  In that case it is also possible and expectable that hangup
                  combined with the read event when the remote closed the
                  connection after having data sent, and that data have not been
                  read from the socket yet.
               2. Experience shows that, when epoll reports a combination of
                  read and hangup event, if will keep reporting that combination
                  even if there are actually no data pending to read from the
                  socket. In that case the only way of determining whether there
                  are data pending is calling read() and comparing the return
                  value against EOF. An application that relies on an exception
                  thrown here will then run into an endless turbo event loop.
               3. Only the application knows whether hangup events are expected
                  or exceptions. If it expects them, it may want its handler to
                  be invoked which will not happen if checkKeyError() throws an
                  exception. If it treats hangup events as exceptions, it will
                  want an exception to be thrown even if it was combined with
                  a read or write event.
        
        Params:
            events = reported events
        
        Returns:
            events
        
        Throws:
            SocketException if key is in an erroneous state

     **************************************************************************/

    protected Event checkKeyError ( Event events )
    {
        if (!(events & (events.Read | events.Write)))
        {
            assertEx(!(events & events.Hangup), this.exception("socket hung up"));
            assertEx(!(events & events.Error),  this.exception("socket error"));
        }

        assertEx(!(events & events.ReadHangup), this.exception("socket hung up on read"));
        
        return events;
    }

    /***************************************************************************

        Key exception -- thrown when a select key is in an erroneous state.

     **************************************************************************/

    static class KeyException : SocketException
    {
        this ( char[] msg = "" ) { super(msg); }
        
        typeof (this) opCall ( char[] msg )
        {
            super.msg.copy(msg);
            return this;
        }
        
        typeof (this) opCall ( char[] msg, char[] file, long line )
        {
            super.msg.copy(msg);
            super.file.copy(file);
            super.line = line;
            return this;
        }
    }}



/*******************************************************************************

    EpollSelectDispatcher with per client timeout functionality.

******************************************************************************/

public class TimeoutEpollSelectDispatcher : EpollSelectDispatcher
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

