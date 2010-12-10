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

module ocean.io.protocol.SelectWriter;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.io.select.protocol.model.ISelectProtocol;

private import ocean.io.select.SelectDispatcher;

private import tango.io.model.IConduit:           ISelectable, OutputStream;

private import tango.io.selector.model.ISelector: Event;

private import tango.core.Exception:              IOException;
private import ocean.core.Exception:              assertEx;

debug   private import tango.util.log.Trace;

/******************************************************************************

    SelectWriter class

 ******************************************************************************/

class SelectWriter : ISelectProtocol
{
    /**************************************************************************

        Class identifier string for message generation
    
     **************************************************************************/

    const ClassId = typeof (this).stringof;
    
    /**************************************************************************

        Sending position in data buffer
    
     **************************************************************************/

    private size_t send_pos = 0;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
            buffer_size = Data buffer size
    
     **************************************************************************/

    public this ( ISelectable conduit, SelectDispatcher dispatcher, size_t buffer_size )
    {
        super(conduit, dispatcher, buffer_size);
    }
    
    /**************************************************************************

        Constructor; uses the default data buffer size
        
        Params:
            conduit     = Conduit to register events for
            dispatcher  = Dispatcher to register conduit for events
    
     **************************************************************************/

    public this ( ISelectable conduit, SelectDispatcher dispatcher )
    {
        super(conduit, dispatcher);
    }
    
    /**************************************************************************

        Returns the identifiers of the event(s) to register for.
        
        (Implements an abstract super class method.)
        
        Returns:
            the identifiers of the event(s) to register for
     
     **************************************************************************/

    final Event events ( )
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

    protected bool handle ( ISelectable conduit )
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
        
        this.send_pos += this.send(super.data[this.send_pos .. $], cast (OutputStream) conduit);
        
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

    private static size_t send ( void[] data, OutputStream conduit )
    out (sent)
    {
        assert (sent <= data.length, "sent too high");
    }
    body
    {
//        debug (Raw) Trace.formatln("<<< {:X2}", data);
        
        size_t sent = conduit.write(data);
        
        assertEx!(IOException)(sent != conduit.Eof, this.ClassId ~ ": end of flow whilst writing");
        
        return sent;
    }
    
    /**************************************************************************

        Returns an identifier string for this instance
        
        (Implements an abstract super class method.)
        
        Returns:
            identifier string for this instance
    
     **************************************************************************/

    debug (DhtClient) char[] id ( )
    {
        return this.ClassId;
    }
}
