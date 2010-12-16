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

module ocean.io.select.protocol.SelectReader;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.protocol.model.ISelectProtocol;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.io.selector.model.ISelector: Event;

private import tango.io.model.IConduit:           ISelectable, InputStream;

private import tango.core.Exception:              IOException;
private import ocean.core.Exception:              assertEx;

private import tango.stdc.errno;



debug   private import tango.util.log.Trace;

/******************************************************************************

    SelectWriter class

 ******************************************************************************/

class SelectReader : ISelectProtocol
{
    /**************************************************************************

        Class identifier string for message generation
    
     **************************************************************************/

    const ClassId = typeof (this).stringof;
    
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

        Returns the identifiers of the event(s) to register for.
        
        (Implements an abstract super class method.)
        
        Returns:
            the identifiers of the event(s) to register for
     
     **************************************************************************/

    final Event events ( )
    {
        return Event.Read | Event.ReadHangup;
//        return cast(Event)(Event.Read | 0x2000); // FIXME: this is only a temporary fix until we have the EPOLLRDHUP event properly integrated
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

    protected bool handle ( )
    {
        if (super.endOfData)
        {
            super.pos = 0;

            this.receive(cast (InputStream) super.conduit);
        }
        
        return super.invokeHandlers();
    }
    
    /**************************************************************************

        Receives data through conduit, using super.data as input buffer, and
        shortens the buffer length to the amount of received data.
        
        Params:
            conduit: input Conduit
     
     **************************************************************************/

    private void receive ( InputStream conduit )
    {
        super.data.length = super.buffer_size;
        
        super.data.length = this.receive(super.data, conduit);
        
        debug (Raw) Trace.formatln(">>> {:X2}", super.data);
    }
    
    /**************************************************************************

        Receives data through conduit.
        
        Params:
            data:    input buffer
            conduit: input Conduit
            
        Returns:
            Number of bytes received which is at most data.length but may be
            less.
     
     **************************************************************************/

    private static size_t receive ( void[] data, InputStream conduit )
    out (received)
    {
        assert(received <= data.length, this.ClassId ~ ": received length too high");
    }
    body
    {
        size_t received = conduit.read(data);

        if ( received == conduit.Eof )
        {
            switch (errno)
            {
                case EAGAIN:
                static if ( EAGAIN != EWOULDBLOCK )
                {
                    case EWOULDBLOCK:
                }
                    received = 0;
                    break;

                default:
                    assertEx!(IOException)(false, this.ClassId ~ ": end of flow whilst reading");
            }
        }

        return received;
    }
    
    /**************************************************************************

        Returns an identifier string for this instance
        
        (Implements an abstract super class method.)
        
        Returns:
            identifier string for this instance
    
     **************************************************************************/
    
    debug (ISelectClient) char[] id ( )
    {
        return this.ClassId;
    }
}
