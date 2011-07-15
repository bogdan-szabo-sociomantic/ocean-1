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

private import ocean.io.select.model.ISelectClient;

private import ocean.time.timeout.model.ITimeoutManager;

private import ocean.core.Array : copy;

private import tango.util.log.Trace;

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
    
        Timeout manager instance; null disables the timeout feature.
    
     **************************************************************************/

    private ITimeoutManager timeout_manager = null;
    
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

        this.exception = new KeyException;
        
        this.selector.open(size, max_events);
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

        Adds a client registration or overwrites an existing one. Calls the
        protected register_() method, which by default does nothing, but allows
        derived classes to add special client registration behaviour.
    
        Params:
            client = client to register
    
        Returns:
            this instance
    
     **************************************************************************/
    
    final public This register ( ISelectClient[] clients ... )
    {
        foreach (client; clients)
        {
            debug ( ISelectClient ) Trace.formatln("{}: Registering client with epoll", client.id);
            this.selector.register( client.conduit,
                                    cast (.Event) (client.events   |
                                                   Event.Hangup    |
                                                   Event.Error),
                                    cast (Object) client);
            
            client.registerTimeout();
        }
        
        return this;
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

        client.unregisterTimeout();

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
        catch
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
            if (this.timeout_manager !is null)
            {
                ulong us_left = timeout_manager.next_expiration_us;
                
                if (us_left < us_left.max)
                {
                    this.select(TimeSpan.fromMicros(us_left));
                }
                else
                {
                    this.select();
                }
            }
            else
            {
                this.select();
            }
            
            this.handleSelectedKeys();
            this.removeUnregisteredClients();
        }
    }

    /***************************************************************************

        Executes an epoll select.

     **************************************************************************/

    protected int select ( TimeSpan timeout = TimeSpan.max )
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

        return this.selector.select(timeout);
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
                bool unregister_key = true;
                
                ISelectClient client = cast (ISelectClient) key.attachment;
                
                Event events = cast (Event) key.events;
                
                debug (ISelectClient)
                {
                    client.connectionInfo(this.connection_info_buffer);
                    Trace.formatln("{}: {}: {:X8}", this.connection_info_buffer, client.id, key.events);
                }

                if (!client.timed_out) try
                {
                    unregister_key = !client.handle(this.checkKeyError(client, events));
                }
                catch (Exception e)
                {
                    debug (ISelectClient) Trace.formatln(typeof(this).stringof ~ "ISelectClient handle exception {}: {}: {:X8}, {} @{}:{}",
                                                         this.connection_info_buffer, client.id, key.events,
                                                         e.msg, e.file, e.line);
                    
                    this.clientError(client, events, e);
                }
                
                if (unregister_key)
                {
                    this.safeUnregister(client);

                    try
                    {
                        client.finalize();
                    }
                    catch ( Exception e )
                    {
                        this.clientError(client, events, e);
                    }
                }
            }
        }
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

        Checks if a key error has occurred.

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
            SocketException if key is in an erroneous state

     **************************************************************************/

    protected Event checkKeyError ( ISelectClient client, Event events )
    {
        if (events & events.Error)
        {
            int errnum;
            
            if (client.getSocketError(errnum, this.exception.msg, "socket error: "))
            {
                throw this.exception(__FILE__, __LINE__);
            }
            else
            {
                this.exception("socket error", __FILE__, __LINE__);
            }
        }

        return events;
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
            this.traceException(client, e);
        }

        try
        {
            client.error(e, events);
        }
        catch ( Exception e )
        {
            // TODO: not sure if we should really Trace here, but I don't know what
            // else to do in this extreme error case!
            // The application programmer definitely needs to know if this is
            // happening. Just throwing may be another option...
            this.traceException(client, e, "Very bad: Exception thrown from inside ISelectClient.error() delegate! -- ");
        }
    }

    /***************************************************************************

        Outputs a client exception message to Trace.

        Params:
            client = client which threw exception
            e = exception thrown
            message = additional message to output

     **************************************************************************/

    private void traceException ( ISelectClient client, Exception e, char[] message = null )
    {
        debug (ISelectClient)
        {
            Trace.format("{}:", client.id);
        }
        else
        {
            if ( e.line )
            {
                Trace.formatln("{} {} @ {}:{}", message, e.msg, e.file, e.line);
            }
            else
            {
                Trace.formatln("{} {}", message, e.msg);
            }
        }
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
}
