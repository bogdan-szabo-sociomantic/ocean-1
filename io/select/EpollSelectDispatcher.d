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

    An eventloop timeout setting is available, through the timeout() method. A
    timeout is considered to have happened if the *whole eventloop* takes longer
    than the specified time to finish -- it is not a timeout per individual
    registered event.

 ******************************************************************************/

module ocean.io.select.EpollSelectDispatcher;

/*******************************************************************************

    Imports

 ******************************************************************************/

private import tango.io.selector.EpollSelector;
private import tango.io.selector.model.ISelector: Event, SelectionKey;
private import tango.io.model.IConduit: ISelectable;

private import tango.core.Exception: SocketException;

private import tango.time.Time: TimeSpan;
private import tango.time.StopWatch;

private import ocean.io.select.model.ISelectClient;

private import ocean.core.Array:     copy;
private import ocean.core.Exception: assertEx;

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

        Timeout: disabled by default

     **************************************************************************/

    private const NoTimeout = TimeSpan.max;

    private TimeSpan timeout_ = NoTimeout;

    /***************************************************************************

        Count of the number of microseconds spent waiting in select. This
        counter is used to detect when a timeout has occurred.

     **************************************************************************/

    private ulong microsecs_in_select;

    /***************************************************************************

        Re-usable list of registered clients, used by the timedOut() method.

     **************************************************************************/

    private ISelectClient[] clients;

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
        
        this.exception = new KeyException;
        
        this.selector.open(size, max_events);
    }
    
    /***************************************************************************

        Destructor
    
     **************************************************************************/
    
    ~this ()
    {
        delete this.selector;
        delete this.exception;
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
    
    public This close ()
    {
        this.selector.close();
        
        return this;
    }

    /***************************************************************************

        Sets the timeout in ms

        Note: this method accepts timeout values as an int, as this is what the
        epoll_wait function (called in tango.io.selector.EpollSelector) expects.

        Params:
            ms = new timeout in ms

        Returns:
            this instance

     **************************************************************************/

    public This timeout ( int ms )
    in
    {
        assert(ms >= 0, typeof(this).stringof ~ ".timeout: negative timeout values have no meaning");
    }
    body
    {
        this.timeout_ = this.timeout_.fromMillis(ms);

        return this;
    }

    /***************************************************************************

        Gets the timeout in ms

        Returns:
            timeout in ms

     **************************************************************************/

    public int timeout ( )
    {
        return this.timeout_.millis();
    }

    /***************************************************************************

        Disables the timeout

        Returns:
            this instance

     **************************************************************************/

    public This disableTimeout ( )
    {
        this.timeout_ = NoTimeout;

        return this;
    }

    /***************************************************************************

        Returns:
            true if timeout is disabled
    
     **************************************************************************/

    public bool timeoutEnabled ( )
    {
        return this.timeout_ != NoTimeout;
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
        this.selector.register( client.conduit,
                                cast (.Event) (client.events   |
                                               Event.Hangup    |
                                               Event.Error),
                                cast (Object) client);
        
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

        return this;
    }

    /***************************************************************************

        While there are clients registered, repeatedly waits for registered
        events to happen, invokes the corresponding event handlers of the
        registered clients and unregisters the clients if they desire so.

        Returns:
            true on normal exit after completion of all registered events, false
            on timeout

     **************************************************************************/

    public bool eventLoop ( )
    {
        if ( this.timeoutEnabled )
        {
            this.microsecs_in_select = 0;
        }

        bool not_timed_out = true;

        while (this.selector.count() && not_timed_out)
        {
            not_timed_out = this.select();

            if ( not_timed_out )
            {
                this.handleSelectedKeys();
            }
            else
            {
                this.timedOut();
            }
        }

        return not_timed_out;
    }

    /***************************************************************************

        Executes an epoll select, including logic for timeout detection, if
        requested.

        Returns:
            true on normal exit after completion of all registered events, false
            on timeout

     **************************************************************************/

    private bool select ( )
    {
        StopWatch sw;
        bool not_timed_out;

        if ( this.timeoutEnabled )
        {
            sw.start;
        }

        int event_count = this.selector.select(this.timeout_);
        not_timed_out = event_count > 0;

        if ( this.timeoutEnabled )
        {
            this.microsecs_in_select += sw.microsec;
            if ( this.microsecs_in_select > this.timeout_.micros )
            {
                not_timed_out = false;
            }
        }

        return not_timed_out;
    }

    /***************************************************************************

        Calls the timeout() method of all registered clients, after a select
        timeout has occurred.

     **************************************************************************/

    private void timedOut ( )
    {
        // Build up a list of all registered clients before calling their
        // timeout() handlers. This needs to be done as the timeout() handler
        // for a client may unregister one or more clients with the select
        // dispatcher, thus causing the list of registered clients to be
        // modified, thus disrupting a normal foreach loop over this.selector.
        this.clients.length = 0;
        foreach ( key; this.selector )
        {
            this.clients ~= cast(ISelectClient)key.attachment;
        }

        // Notify each client that a timeout occurred.
        foreach ( client; this.clients )
        {
            client.timeout();
        }
    }

    /***************************************************************************

        Calls the handle() method of all selected clients.

     **************************************************************************/

    private void handleSelectedKeys ( )
    {
        foreach (key; this.selector.selectedSet())
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
                unregister_key = !client.handle(this.checkKeyError(events));
            }
            catch (Exception e)
            {
                unregister_key = true;
                
                debug (ISelectClient) Trace.formatln("{}: {}", client.id, e.msg);

                client.error(e, events);
            }
            finally if (unregister_key)
            {
                this.selector.unregister(key.conduit);

                client.finalize();
            }
        }
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
