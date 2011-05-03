module ocean.io.select.fiberprotocol.SelectReader;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import tango.io.model.IConduit: InputStream;

private import tango.stdc.errno;

debug ( Raw ) private import tango.util.log.Trace;

class SelectReader : ISelectProtocol
{
    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit, fiber);
    }
    
    protected bool transmit_ ( )
    {
        super.data.length = super.buffer_size;
        
        super.data.length = this.receive();
        
        debug (Raw) Trace.formatln(">>> {:X2}", super.data);

        return super.data.length < 5;
    }

    private size_t receive ( )
    out (received)
    {
        assert(received <= data.length, typeof(this).stringof ~ ": received length too high");
    }
    body
    {
        size_t received = (cast (InputStream) super.conduit).read(super.data);

        if ( received == InputStream.Eof )
        {
            switch (errno)
            {
                default:
                    throw super.exception("end of flow whilst reading", __FILE__, __LINE__);
                
                case EAGAIN:
                    static if ( EAGAIN != EWOULDBLOCK )
                    {
                        case EWOULDBLOCK:
                    }
                    received = 0;
                    break;
            }
        }

        return received;
    }

    Event events ( )
    {
        return Event.Read;
    }
}
