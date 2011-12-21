/*******************************************************************************

    Manages an I/O event loop with automatic handler invocation and
    unregistration.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    The EpollSelectDispatcher class wraps a Tango EpollSelector and uses
    ISelectClient instances for Select I/O event registration, unregistration
    and event handler invocation. An I/O event loop is provided that runs while
    there are select event registrations. This loop automatically invokes the
    registered handlers; via the return value each handler may indicate that it
    wishes to be unregistered. After the ISelectClient instance has been
    unregistered, its finalize() method is invoked.

    If a handler throws an Exception, it is caught, the ISelectClient containing
    that handler is unregistered immediately and finalize() is invoked.
    Exceptions thrown by the ISelectClient's finalize() methods are also caught.

*******************************************************************************/

module ocean.io.select.EpollSelectDispatcher;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.event.SelectEvent;

private import ocean.core.Array : copy;
private import ocean.core.ArrayMap;

private import ocean.core.AppendBuffer;

private import ocean.core.Exception : assertEx;

private import ocean.time.timeout.model.ITimeoutClient,
               ocean.time.timeout.model.ITimeoutManager: ITimeoutManager;

private import tango.io.selector.EpollSelector;
private import tango.io.selector.model.ISelector : Event, SelectionKey;
private import tango.io.selector.SelectorException : UnregisteredConduitException;

private import tango.time.Time: TimeSpan;

private import tango.core.Exception : IOException, SocketException;

debug (ISelectClient) private import ocean.util.log.Trace;

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

    private const EpollSelector selector;

    /***************************************************************************

        Re-usable exceptions

     **************************************************************************/

    private const KeyException key_exception;

    private const EventLoopException eventloop_exception;

    /***************************************************************************

        String buffer used for connection info debug printouts

     **************************************************************************/

    debug (ISelectClient) private char[] connection_info_buffer;

    /***************************************************************************

        Re-useable list of keys to be handled. After a select is performed, this
        list is filled by the seperateClientLists() method. Note that any
        clients which have timed out will *not* be included in this list (and
        thus will not be handled).

     **************************************************************************/

    private alias AppendBuffer!(SelectionKey) SelectedKeysList;

    private const SelectedKeysList selected_keys;

    /***************************************************************************

        Re-useable set of timed out clients. After a select is performed, this
        list is filled by the seperateClientLists() method. Note that any
        clients in this list will *not* be handled, even if they have fired.

        The list of timed out clients is stored as a set so that clients which
        have fired after select can easily check whether they've timed out.

     **************************************************************************/

    private alias Set!(ISelectClient) TimedOutClientList;

    private const TimedOutClientList timed_out_clients;
    
    /***************************************************************************
    
        Timeout manager instance; null disables the timeout feature.
    
     **************************************************************************/

    private const ITimeoutManager timeout_manager;
    
    /***************************************************************************

        Event which is triggered when the shutdown() method is called.

     **************************************************************************/

    private const SelectEvent shutdown_event;

    /***************************************************************************

        Flag which the eventLoop checks for exit status. Set to true when the
        shutdown event fires (via calling the shutdown() method).

     **************************************************************************/

    private bool shutdown_triggered;

    /***************************************************************************

        Flag set to true when the eventLoop() method is called, and to false
        when it exits. Used to detect if the event loop is started from within
        itself (in which case an exception is thrown).

     **************************************************************************/

    private bool in_event_loop;

    /***************************************************************************

        Constructor

        Params:
            timeout_manager = timeout manager instance (null disables the
                              timeout feature)
            size            = value that provides a hint for the maximum amount
                              of conduits that will be registered
            max_events      = value that provides a hint for the maximum amount
                              of conduit events that will be returned in the
                              selection set per call to select.

     **************************************************************************/

    this ( ITimeoutManager timeout_manager,
           uint size       = EpollSelector.DefaultSize,
           uint max_events = EpollSelector.DefaultMaxEvents )
    {
        this.selector = new EpollSelector;
        
        this.timeout_manager = timeout_manager;

        this.key_exception = new KeyException;
        this.eventloop_exception = new EventLoopException;        

        this.selector.open(size, max_events);

        this.shutdown_event = new SelectEvent(&this.shutdownTrigger);
        
        this.selected_keys = new SelectedKeysList(max_events);
        this.timed_out_clients = new TimedOutClientList;
    }
    
    /***************************************************************************

        Constructor; disables the timeout feature.
    
        Params:
            size            = value that provides a hint for the maximum amount
                              of conduits that will be registered
            max_events      = value that provides a hint for the maximum amount
                              of conduit events that will be returned in the
                              selection set per call to select.
    
     **************************************************************************/

    this ( uint size       = EpollSelector.DefaultSize,
           uint max_events = EpollSelector.DefaultMaxEvents )
    {
        this(null, size, max_events);
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

        Returns:
            true if this select dispatcher supports per-IO operation timeout for
            registered clients
    
     **************************************************************************/

    public bool timeout_enabled ( )
    {
        return this.timeout_manager !is null;
    }
    
    /***************************************************************************

        Adds a client registration or overwrites an existing one.
    
        Params:
            client = client to register
    
        Returns:
            true if a client registration was actually added or modified or
            false if the file descriptor of client was already registered for
            the same event as client.event. 
    
     **************************************************************************/
    
    final public bool register ( ISelectClient client )
    {
        debug ( ISelectClient ) Trace.formatln("{}: Registering client with epoll (fd={})",
                client.id, client.conduit.fileHandle);

        bool register = true;

        auto existing_key = this.selector.key(client.conduit);

        if ( existing_key != existing_key.init )
        {
            register = existing_key.events != client.events;

            // TODO: might be more efficient to have a re-register method,
            // which would only require the ebtree to be re-sorted once
            // (rather than once on removal and once on adding)
            ISelectClient existing_client = cast (ISelectClient)existing_key.attachment;
            existing_client.unregisterTimeout();
        }

        if ( register )
        {
            this.selector.register(client.conduit,
                                   cast (.Event) (client.events   |
                                                  Event.Hangup    |
                                                  Event.Error),
                                                  cast (Object) client);
        }
        
        client.registerTimeout();
        client.registered();
        
        return register;
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
        debug ( ISelectClient ) Trace.formatln("{}: Unregistering client from epoll (fd={})",
                client.id, client.conduit.fileHandle);

        this.selector.unregister(client.conduit);

        client.unregisterTimeout();
        client.unregistered();

        return this;
    }

    /**************************************************************************

        Unregisters the chain of io handlers with the select dispatcher. The
        internal data buffer is cleared. An exception is not thrown on
        unregistration error (which may occur if the client is not registered).

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
        catch
        {
        }

        return this;
    }
    
    /**************************************************************************

        Sets a timeout manager expiry registration to client if the timeout
        feature is enabled. This must be done exactly once for each select
        client that should be able to time out.
        If the timeout feature is disabled, nothing is done.
        
        Params:
            client = client to set timeout manager expiry registration
        
        Returns:
            true on success or false if the timeout feature is disabled.
        
     **************************************************************************/

    public bool setExpiryRegistration ( ISelectClient client )
    {
        if (this.timeout_enabled)
        {
            client.expiry_registration = this.timeout_manager.getRegistration(client);
            return true;
        }
        else
        {
            return false;
        }
    }
    
    /***************************************************************************

        Causes the event loop to exit before entering the next wait cycle.

        Note that after calling shutdown() the select dispatcher is left in an
        invalid state, where register() and unregister() calls will cause seg
        faults and further calls to eventLoop() will exit immediately.
        (See TODO in eventLoop().)

     **************************************************************************/

    public void shutdown ( )
    {
        this.register(this.shutdown_event);
        this.shutdown_event.trigger();
    }

    /***************************************************************************

        While there are clients registered, repeatedly waits for registered
        events to happen, invokes the corresponding event handlers of the
        registered clients and unregisters the clients if they desire so.
        
        TODO: Suggest using assert() instead of maintaining a reusable exception
              instance: It is simply a program error to run multiple
              eventLoop()s simultaneously that must be avoided by  application
              code.
        
     **************************************************************************/

    public void eventLoop ( )
    {
        if ( this.in_event_loop )
        {
            throw this.eventloop_exception;
        }

        if ( this.shutdown_triggered )
        {
            this.selector.open();

            this.shutdown_triggered = false;
        }
        
        this.in_event_loop = true;
        scope ( exit ) this.in_event_loop = false;

        while ( this.selector.count() )
        {
            this.select();

            this.handleSelectedKeys();

            this.handleTimedOutClients();

            if ( this.shutdown_triggered )
            {
                this.selector.close();

                return;
            }
        }
    }

    /***************************************************************************

        Converts a microseconds value to milliseconds for use in select().
        It is crucial that this conversion always rounds up. Otherwise the
        timeout manager might not find a timed out client after select() has
        reported a timeout.
        
        Params:
            us = time value in microseconds
            
        Returns:
            nearest time value in milliseconds that is not less than us.
        
     **************************************************************************/

    private static ulong usToMs ( ulong us )
    {
        ulong ms = us / 1000;
        
        return ms + ((us - ms * 1000) != 0); 
    }
    
    /***************************************************************************

        Executes an epoll select.
        
        Returns:
            The amount of conduits that have received events; 0 if no conduits
            have received events within the timeout; and -1 if the wakeup()
            method has been called from another thread.
        
     **************************************************************************/

    protected int select ( )
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

        ulong us_left = (this.timeout_manager !is null)
                        ? timeout_manager.us_left
                        : ulong.max;

        bool have_timeout = us_left < us_left.max;

        auto timeout = have_timeout
                       ? TimeSpan.fromMillis(this.usToMs(us_left))
                       : TimeSpan.max;

        auto num_selected = this.selector.select(timeout);

        debug ( ISelectClient ) if ( num_selected == 0 )
        {
            Trace.formatln("{}.select: timed out after {}microsec",
                    typeof(this).stringof, us_left);
        }

        // TODO: rather than have_timeout, shouldn't we pass selected_keys == 0
        // here?
        this.separateClientLists(have_timeout);

        return num_selected;
    }
    
    /***************************************************************************

        Calls the handle() method of all selected clients.

     **************************************************************************/

    protected void handleSelectedKeys ( )
    {
        foreach ( key; this.selected_keys[] )
        {
            ISelectClient client = cast (ISelectClient) key.attachment;
            
            Event events = cast (Event) key.events;
            
            debug (ISelectClient)
            {
                client.connectionInfo(this.connection_info_buffer);
                Trace.formatln("Epoll firing {}: {} (fd={}) : {:X8}",
                        this.connection_info_buffer, client.id,
                        client.conduit.fileHandle, key.events);
            }

            bool unregister_key = true;

            try
            {
                unregister_key = !client.handle(this.checkKeyError(client, events));
                debug ( ISelectClient ) if ( unregister_key )
                {
                    Trace.formatln("{}: Client finished, unregistering (fd={})",
                            client.id, client.conduit.fileHandle);
                }
            }
            catch (Exception e)
            {
                debug (ISelectClient)
                {
                    Trace.formatln(typeof(this).stringof ~ " ISelectClient handle exception {}: {}: {:X8}, {} @{}:{}",
                                                         this.connection_info_buffer, client.id, key.events,
                                                         e.msg, e.file, e.line);
                }

                this.clientError(client, events, e);
            }

            if (unregister_key)
            {
                this.unregisterAndFinalize(client);
            }
        }
    }

    /***************************************************************************

        Finalizes all timed out clients (as determined by
        separateClientLists()).

    ***************************************************************************/

    protected void handleTimedOutClients ( )
    {
        foreach ( client; this.timed_out_clients )
        {
            this.unregisterAndFinalize(client);
        }
    }

    /***************************************************************************

        Checks if a selection key error has occurred by checking events and
        querying a socket error.

        Hangup states are not checked here, for the following reasons:
            1. The hangup event is not an error on its own and may be expected
               to happen, e.g. when short term connections are used. In that
               case it is also possible and expectable that hangup combined with
               the read event when the remote closed the connection after having
               data sent, and that data have not been read from the socket yet.
            2. Experience shows that, when epoll reports a combination of read
               and hangup event, if will keep reporting that combination even if
               there are actually no data pending to read from the socket. In
               that case the only way of determining whether there are data
               pending is calling read() and comparing the return value against
               EOF. An application that relies on an exception thrown here will
               then run into an endless turbo event loop.
            3. Only the application knows whether hangup events are expected or
               exceptions. If it expects them, it may want its handler to be
               invoked which will not happen if checkKeyError() throws an
               exception. If it treats hangup events as exceptions, it will want
               an exception to be thrown even if it was combined with a read or
               write event.

        Params:
            events = reported events

        Returns:
            events

        Throws:
            IOException if a selection key error has occurred or SocketException
            if a socket error is reported. (SocketException is derived from
            IOException.)

     **************************************************************************/

    protected Event checkKeyError ( ISelectClient client, Event events )
    {
        if (events & events.Error)
        {
            int errnum;
            
            if (client.getSocketError(errnum, this.key_exception.msg, "socket error: "))
            {
                IOException e = this.key_exception(__FILE__, __LINE__);
                throw e;
            }
            else
            {
                this.key_exception("socket error", __FILE__, __LINE__);
            }
        }

        return events;
    }

    /***************************************************************************

        After a call to this.selector.select(), separates registered clients
        into two lists:
            1. Clients which have timed out (added to this.timed_out_clients)
            2. Clients which have fired (added to this.timed_out_clients)

        Params:
            have_timeout = tells whether select was passed a timeout value

    ***************************************************************************/

    private void separateClientLists ( bool have_timeout )
    {
        this.selected_keys.clear();
        this.timed_out_clients.clear();

        if ( have_timeout )
        {
            this.timeout_manager.checkTimeouts((ITimeoutClient timeout_client)
            {
                auto client = cast (ISelectClient)timeout_client;
                
                assert (client !is null, "timeout client is not a select client");
                
                debug ( ISelectClient ) Trace.formatln("{}: Client timed out, unregistering (fd={})",
                        client.id, client.conduit.fileHandle);
                this.timed_out_clients.put(client);
                return true;
            });
        }

        auto selected_set = this.selector.selectedSet();

        if ( selected_set !is null ) // EpollSelector.selectedSet() can return null
        {
            foreach ( key; selected_set )
            {
                ISelectClient client = cast (ISelectClient) key.attachment;
                if ( !(client in this.timed_out_clients) )
                {
                    this.selected_keys ~= key;
                }
            }
        }
    }

    /***************************************************************************

        Unregisters and finalizes a select client. Any errors which occur while
        calling the client's finalizer are caught and reported to the client's
        error() method.

        Params:
            client = client to finalize

    ***************************************************************************/

    private void unregisterAndFinalize ( ISelectClient client )
    {
        this.safeUnregister(client);
        
        try
        {
            client.finalize();
        }
        catch ( Exception e )
        {
            debug (ISelectClient)
            {
                if ( e.line )
                {
                    Trace.formatln("Error while finalizing client {}: {} @ {}:{}", client.id, e.msg, e.file, e.line);
                }
                else
                {
                    Trace.formatln("Error while finalizing client {}: {}", client.id, e.msg);
                }
            }
            this.clientError(client, Event.None, e);
        }
    }

    /***************************************************************************

        Called when the shutdown event fires (via a call to the shutdown()
        method). Sets the shutdown flag, ensuring that the event loop will exit,
        regardless of whether there are any clients still registered.

        Returns:
            true to stay registered in the selector
    
     **************************************************************************/

    private bool shutdownTrigger ( )
    {
        this.shutdown_triggered = true;

        return true;
    }

    /***************************************************************************

        Called when an exception is thrown while handling a client (either the
        handle() or finalize() method).

        Calls the client's error() method, and in debug builds ouputs a message.

        Params:
            client = client which threw exception
            events = epoll events which fired for client
            e = exception thrown

     **************************************************************************/

    private void clientError ( ISelectClient client, Event events, Exception e )
    {
        debug (ISelectClient)
        {
            if ( e.line )
            {
                Trace.formatln("{}: {} @ {}:{}", client.id, e.msg, e.file, e.line);
            }
            else
            {
                Trace.formatln("{}: {}", client.id, e.msg);
            }
        }

        client.error(e, events);
    }

    /***************************************************************************

        Key exception -- thrown when a select key is in an erroneous state.

     **************************************************************************/

    static class KeyException : SocketException
    {
        this ( char[] msg = "" )
        {
            super(msg);
        }
        
        typeof (this) opCall ( char[] msg )
        {
            super.msg.copy(msg);
            return this;
        }
        
        typeof (this) opCall ( char[] file, long line )
        {
            super.file.copy(file);
            super.line = line;
            return this;
        }
        
        typeof (this) opCall ( char[] msg, char[] file, long line )
        {
            return this.opCall(msg).opCall(file, line);
        }
    }
    
    /***************************************************************************

        Event loop exception -- thrown when the event loop is called from within
        an event handler while the event loop is already running.

    ***************************************************************************/
    
    static class EventLoopException : Exception
    {
        this ( ) { super("eventLoop called from within ISelectClient callback"); }
    }
}
