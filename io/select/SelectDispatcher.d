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

module ocean.io.select.SelectDispatcher;

/*******************************************************************************

    Imports

 ******************************************************************************/

private import tango.core.Exception: SocketException;

private import tango.io.selector.AbstractSelector;
private import tango.io.selector.model.ISelector: Event, SelectionKey;
private import tango.io.model.IConduit: ISelectable;

private import tango.time.Time: TimeSpan;

private import ocean.io.select.model.ISelectClient;

private import ocean.core.Exception: assertEx;

debug   import tango.util.log.Trace;

/*******************************************************************************

    SelectDispatcher

 ******************************************************************************/

class SelectDispatcher
{
    /***************************************************************************

        This alias for chainable methods

     **************************************************************************/

    alias typeof (this) This;

    /***************************************************************************

        Wrapped AbstractSelector instance

     **************************************************************************/

    private AbstractSelector selector;

    /***************************************************************************

        Timeout: (almost) infinite by default

     **************************************************************************/

    private TimeSpan timeout_ = TimeSpan.max;

    /***************************************************************************

        Workaround to avoid crashes when using a SelectSelect; used in
        dispatch() below

     **************************************************************************/

    version (SelectSelect) private bool[ISelectable.Handle] registry;

    /***************************************************************************

        Constructor

        Params:
            selector = Selector instance to use. This instance is considered to
                       be owned by the SelectDispatcher and deleted in the
                       destructor; do not use it otherwise nor delete it.
            size     = value that provides a hint for the maximum amount of
                       conduits that will be registered
            max      = value that provides a hint for the maximum amount of
                       conduit events that will be returned in the selection set
                       per call to select.

     **************************************************************************/

    this ( AbstractSelector selector, uint size, uint maxEvents )
    {
        this.selector = selector;

        selector.open(size, maxEvents);
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
    
    public This open ( uint size, uint maxEvents )
    {
        this.selector.open(size, maxEvents);
        
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
                                client.events   |
                                Event.Hangup    |
                                Event.Error     |
                                Event.InvalidHandle,
                                cast (Object) client);

        version (SelectSelect) this.registry[client.conduit.fileHandle] = true;

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
            SocketException if key is in an erraneous state or on selection
            timeout
        
     **************************************************************************/

    public This eventLoop ( )
    {
        while (this.selector.count())
        {
            int event_count = this.selector.select(this.timeout_);

            assertEx!(SocketException)(event_count > 0, "select timeout");
            foreach (key; this.selector.selectedSet())
            {
                bool unregister_key = false;
                
                ISelectClient client = cast (ISelectClient) key.attachment;
                
                version (SelectSelect) scope (exit) if (!this.registry.length) break; // FIXME: required for SelectSelect not to crash
                
                try
                {
                    this.checkKeyError(key);
                    
                    unregister_key = !client.handle(key.conduit, key.events);
                }
                catch (Exception e)
                {
                    client.error(e, key.events);
                    
                    unregister_key = true;
                }
                finally if (unregister_key)
                {
                    this.selector.unregister(key.conduit);

                    version (SelectSelect) this.registry.remove(key.conduit.fileHandle);
                    
                    client.finalize();
                }
            }
        }

        return this;
    }
    
    /***************************************************************************

        Checks if key is in an erraneous state.
        
        Params:
            key = selection key
        
        Throws:
            SocketException if key is in an erraneous state
    
     **************************************************************************/

    private static void checkKeyError ( SelectionKey key )
    {
        if (!(key.isReadable() || key.isWritable() || key.isUrgentRead()))
        {
            assertEx!(SocketException)(!key.isHangup(),        "socket hung up");
            assertEx!(SocketException)(!key.isInvalidHandle(), "socket: invalid handle");
            assertEx!(SocketException)(!key.isError(),         "socket error");
        }
    }
    
    /***************************************************************************

        Destructor

     **************************************************************************/

    ~this ()
    {
        delete this.selector;
    }
}
