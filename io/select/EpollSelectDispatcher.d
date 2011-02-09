/*******************************************************************************

    Wraps a Tango AbstractSelector and manages an I/O event loop with automatic
    handler invocation and unregistration.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

    The SelectDispatcher class wraps a Tango AbstractSelector and uses
    ISelectClient instances for Select I/O event registration, unregistration
    and event handler invocation. An I/O event loop is provided that runs while
    there are Select event registrations. This loop automatically invokes the
    registered handlers; via the return value each handler may indicate that it
    wishes to be unregistered. After the ISelectClient instance has been
    unregistered, its finalize() method is invoked.
    If a handler throws an Exception, it is caught, the ISelectClient containing
    that handler is unregistered immediately and finalize() is invoked.
    Exceptions thrown by the ISelectClient's finalize() methods are not caught. 
    
    Note that the AbstractSelector instance passed to the constructor is
    considered to be owned by the SelectDispatcher and deleted in the
    SelectDispatcher destructor; do not use that instance otherwise nor delete
    it.

 ******************************************************************************/

module ocean.io.select.EpollSelectDispatcher;

//public import ocean.io.select.epoll.Epoll;

//alias Epoll EpollSelectDispatcher;


/*******************************************************************************

    Imports

 ******************************************************************************/

private import tango.io.selector.EpollSelector;
private import tango.io.selector.model.ISelector: Event, SelectionKey;
private import tango.io.model.IConduit: ISelectable;

private import tango.core.Exception: SocketException;

private import tango.time.Time: TimeSpan;

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

        Timeout: (almost) infinite by default

     **************************************************************************/

    private TimeSpan timeout_ = TimeSpan.max;
    
    private KeyException exception;
    
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

        Params:
            ms = new timeout in ms

        Returns:
            this instance

     **************************************************************************/

    public This timeout ( long ms )
    {
        this.timeout_ = this.timeout_.fromMillis(ms);

        return this;
    }

    /***************************************************************************

        Gets the timeout in ms

        Returns:
            timeout in ms

     **************************************************************************/

    public long timeout ( )
    {
        return this.timeout_.millis();
    }

    /***************************************************************************

        Resets the timeout to (almost) infinite

        Returns:
            this instance

     **************************************************************************/

    public This disableTimeout ( )
    {
        this.timeout_ = this.timeout_.init;

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
            this instance
        
        Throws:
            SocketException if key is in an erroneous state or on selection
            timeout
        
     **************************************************************************/

    debug (ISelectClient) private char[] connection_info_buffer;

    public bool eventLoop ( )
    {
        bool not_timed_out = true;
        
        while (this.selector.count() && not_timed_out)
        {
            int event_count = this.selector.select(this.timeout_);
            
            not_timed_out = event_count >= 0;
            
            if (not_timed_out) foreach (key; this.selector.selectedSet())
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
                    debug (ISelectClient) Trace.formatln("{}: {}", client.id, e.msg);

                    client.error(e, events);

                    unregister_key = true;
                }
                finally if (unregister_key)
                {
                    this.selector.unregister(key.conduit);

                    client.finalize();
                }
            }
        }

        if ( !not_timed_out )
        {
            // TODO: call error delegate with timeout code
        }

        return not_timed_out;
    }
    
    /***************************************************************************

        Checks if key is in an erraneous state.
        
        Params:
            key = selection key
        
        Throws:
            SocketException if key is in an erraneous state
    
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
