/******************************************************************************

    Binary data I/O protocol writer for Select event-driven, non-blocking I/O
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    For detailed information how to register an SelectWriter instance for events
    for an I/O device, see ISelectProtocol documentation.
    
    To implement the same protocol as ocean.io.protocol.Writer, call a method
    from ocean.io.protocol.serializer.SelectSerializer from within the IOHandlers.
    
 ******************************************************************************/

module ocean.io.select.protocol.chain.ChainSelectWriter;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.io.select.protocol.chain.model.IChainSelectProtocol;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.model.IConduit:           ISelectable, OutputStream;

private import tango.io.selector.model.ISelector: Event;

private import tango.core.Exception:              IOException;

debug   private import ocean.util.log.Trace;

/******************************************************************************

    SelectWriter class

 ******************************************************************************/

class ChainSelectWriter : IChainSelectProtocol
{
    /**************************************************************************

        Sending position in data buffer
    
     **************************************************************************/

    private size_t send_pos = 0;
    
    /**************************************************************************

        Alias for a delegate to be called when data is sent.
    
     **************************************************************************/

    public alias void delegate ( void[] ) SentCallback;

    /**************************************************************************

        Delegate to be called when data is sent.
    
     **************************************************************************/

    private SentCallback on_sent;

    /**************************************************************************

        Constructor
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
            buffer_size = Data buffer size
    
     **************************************************************************/

    public this ( ISelectable conduit, EpollSelectDispatcher dispatcher, size_t buffer_size )
    {
        super(conduit, dispatcher, buffer_size);
    }
    
    /**************************************************************************

        Constructor; uses the default data buffer size
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
    
     **************************************************************************/

    public this ( ISelectable conduit, EpollSelectDispatcher dispatcher )
    {
        super(conduit, dispatcher);
    }
    
    /**************************************************************************

        Sets a delegate to be called when data is sent.
        
        Params:
            on_sent = delegate to call when data is sent
    
     **************************************************************************/
    
    public void sentCallback ( SentCallback on_sent )
    {
        this.on_sent = on_sent;
    }

    /**************************************************************************

        Returns the identifiers of the event(s) to register for.
        
        (Implements an abstract super class method.)
        
        Returns:
            the identifiers of the event(s) to register for
     
     **************************************************************************/

    final public Event events ( )
    {
        return Event.Write;
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
        bool more      = false;
        
        if (this.send_pos >= super.data.length)
        {
            super.pos         = 0;
            this.send_pos    = 0;
            
            super.data.length = super.buffer_size;
        }
        
        if (!super.endOfData)
        {
            more = super.invokeHandlers();
        }
        
        super.data.length = super.pos;
        
        auto send_data = super.data[this.send_pos .. super.data.length];
        this.send_pos += this.send(send_data, cast (OutputStream) super.conduit);

        if ( this.on_sent )
        {
            this.on_sent(send_data);
        }

        return more || (this.send_pos < super.data.length);
    }

    /**************************************************************************

        Sends data through conduit.
        
        Params:
            data:    output buffer
            conduit: output Conduit
            
        Returns:
            Number of bytes sent which is at most data.length but may be less.
     
     **************************************************************************/

    private size_t send ( void[] data, OutputStream conduit )
    out (sent)
    {
        assert (sent <= data.length, "sent too high");
    }
    body
    {
        debug (Raw) Trace.formatln("<<< {:X2}", data);
        
        size_t sent = conduit.write(data);

        const msg = typeof(this).stringof ~ ": end of flow whilst writing";

        super.warning_e.assertEx(sent != conduit.Eof, msg);

        return sent;
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

