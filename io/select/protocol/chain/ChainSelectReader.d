/******************************************************************************

    Binary data I/O protocol reader for Select event-driven, non-blocking I/O
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    For detailed information how to register an SelectWriter instance for events
    for an I/O device, see ISelectProtocol documentation.
    
    To implement the same protocol as ocean.io.protocol.Writer, call a method
    from ocean.io.protocol.serializer.SelectDeserializer from within the IOHandlers.
    
 ******************************************************************************/

module ocean.io.select.protocol.chain.ChainSelectReader;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.protocol.chain.model.IChainSelectProtocol;

private import ocean.io.select.protocol.generic.ReadConduit;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.model.IConduit: ISelectable, InputStream;

private import tango.stdc.errno;

debug   private import tango.util.log.Trace;

/******************************************************************************

    SelectReader class

 ******************************************************************************/

class ChainSelectReader : IChainSelectProtocol
{
    /**************************************************************************

        Class identifier string for message generation
    
     **************************************************************************/

    const ClassId = typeof (this).stringof;
    
    /**************************************************************************

        Alias for a delegate to be called when data is received.

     **************************************************************************/

    public alias void delegate ( void[] ) ReceivedCallback;

    /**************************************************************************

        Delegate to be called when data is received.
    
     **************************************************************************/

    private ReceivedCallback on_received;
    
    /**************************************************************************

        Data receiver
    
     **************************************************************************/

    private ReadConduit      readConduit;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit     = Input conduit
            dispatcher  = Dispatcher to register conduit for events
            buffer_size = Data buffer size
    
     **************************************************************************/
    
    public this ( ISelectable conduit, EpollSelectDispatcher dispatcher, size_t buffer_size )
    in
    {
        assert ((cast (InputStream) conduit) !is null);
    }
    body
    {
        super(conduit, dispatcher, buffer_size);
        this.readConduit = new ReadConduit(cast (InputStream) conduit, super.warning_e, super.error_e);
    }
    
    /**************************************************************************
    
        Constructor; uses the default data buffer size
        
        Params:
            conduit     = Input conduit
            dispatcher  = Dispatcher to register conduit for events
    
     **************************************************************************/
    
    public this ( ISelectable conduit, EpollSelectDispatcher dispatcher )
    in
    {
        assert ((cast (InputStream) conduit) !is null);
    }
    body
    {
        super(conduit, dispatcher);
        this.readConduit = new ReadConduit(cast (InputStream) conduit, super.warning_e, super.error_e);
    }

    /**************************************************************************

        Sets a delegate to be called when data is received.
        
        Params:
            on_received = delegate to call when data is received

     **************************************************************************/

    public void receivedCallback ( ReceivedCallback on_received )
    {
        this.on_received = on_received;
    }

    /**************************************************************************

        Returns the identifiers of the event(s) to register for.
        
        (Implements an abstract super class method.)
        
        Returns:
            the identifiers of the event(s) to register for
     
     **************************************************************************/

    final public Event events ( )
    {
        return Event.Read | Event.ReadHangup;
    }
    
    /**************************************************************************

        Handles the current event which just occurred on conduit.
        
        (Implements an abstract super class method.)
        
        Params:
            conduit: Conduit for which the event occurred
            
        Returns:
            true if the method should be called again when the event occurs next
            time or false if finished
     
     **************************************************************************/

    protected bool handle_ ( Event events )
    {
        if (super.endOfData)
        {
            super.pos = 0;

            this.receive(cast (InputStream) super.conduit, events);
        }
        
        return super.invokeHandlers();
    }
    
    /**************************************************************************

        Receives data through conduit, using super.data as input buffer, and
        shortens the buffer length to the amount of received data.
        
        Params:
            conduit: input Conduit
     
     **************************************************************************/

    private void receive ( InputStream conduit, Event events )
    {
        super.data.length = super.buffer_size;

        super.data.length = this.readConduit(super.data, events);

        debug (Raw) Trace.formatln(">>> {:X2}", super.data);

        if ( this.on_received )
        {
            this.on_received(super.data);
        }
    }

    /**************************************************************************

        Returns an identifier string for this instance
        
        (Implements an abstract super class method.)
        
        Returns:
            identifier string for this instance
    
     **************************************************************************/
    
    debug char[] id ( )
    {
        return typeof (this).stringof;
    }
}

