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

// TODO: it'd be cool to have a base class select dispatcher without any of the timeout
// management (a dht node, for example, has no need of this stuff at all). Then
// a more complex dispatcher could be derived from the base, adding the extra
// timeout functionality.


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

    SelectDispatcher

 ******************************************************************************/

class EpollSelectDispatcher
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

        Timeout manager instance

     **************************************************************************/

    private TimeoutManager timeout_manager;

    /***************************************************************************

        Count of the number of microseconds spent waiting in select. This
        counter is used to detect when a timeout has occurred.

     **************************************************************************/

    private ulong microsecs_in_select;

    /***************************************************************************

        Re-usable list of clients to be unregistered clients, used by the
        unregisterAfterSelect() method.

     **************************************************************************/

    private ISelectClient[] clients_to_unregister;

    /***************************************************************************

        Re-usable exception

     **************************************************************************/

    private KeyException exception;

    /***************************************************************************

        String buffer used for connection info debug printouts

     **************************************************************************/

    debug (ISelectClient) private char[] connection_info_buffer;

    /***************************************************************************

        Constructor

        Params:
            selector =   Selector instance to use. This instance is considered
                         to be owned by the SelectDispatcher and deleted in the
                         destructor; do not use it otherwise nor delete it.
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

        this.timeout_manager = new TimeoutManager;

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

        Adds a client registration or overwrites an existing one

        Params:
            client = client to register

        Returns:
            this instance

     **************************************************************************/

    public This register ( ISelectClient client )
    {
        debug ( ISelectClient ) Trace.formatln("{}: Registering client with epoll, client's timeout is {}ms", client.id, client.getTimeout);
        this.selector.register( client.conduit,
                                cast (.Event) (client.events   |
                                               Event.Hangup    |
                                               Event.Error),
                                cast (Object) client);

        this.timeout_manager.register(client);

        return this;
    }

   /****************************************************************************

       Removes a client registration

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

        this.timeout_manager.unregister(client);

        return this;
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
            this.timeout_manager.checkTimeouts();
            this.handleSelectedKeys();
            this.removeUnregisteredClients();
        }
    }

    /***************************************************************************

        Executes an epoll select, including logic for timeout detection, if
        requested.

     **************************************************************************/

    private void select ( )
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

        int event_count = this.selector.select(this.timeout_manager.getTimeout);
    }

    /***************************************************************************

        Calls the handle() method of all selected clients.

     **************************************************************************/

    private void handleSelectedKeys ( )
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
                    if ( this.timeout_manager.timedOut(client) )
                    {
                        unregister_key = true;
                    }
                    else
                    {
                        unregister_key = !client.handle(this.checkKeyError(events));
                    }
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

        Unregisters any clients which were requested for removal by the
        unregisterAfterSelect() method.

     **************************************************************************/

    private void removeUnregisteredClients ( )
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

        Params:
            key = selection key

        Throws:
            SocketException if key is in an erroneous state

     **************************************************************************/

    private Event checkKeyError ( Event events )
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
    }
}
