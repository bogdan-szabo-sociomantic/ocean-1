module ocean.io.select.fiberprotocol.SelectReader;

private import ocean.core.Exception;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import tango.io.model.IConduit;
private import tango.core.Exception;

private import tango.core.Thread : Fiber;

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
        
        super.data.length = this.receive(super.data, cast (InputStream) super.conduit);
        
        debug (Raw) Trace.formatln(">>> {:X2}", super.data);

        return super.data.length < 5;
    }

    private static size_t receive ( void[] data, InputStream conduit )
    out (received)
    {
        assert(received <= data.length, typeof(this).stringof ~ ": received length too high");
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
                    assertEx!(IOException)(false, typeof(this).stringof ~ ": end of flow whilst reading");
            }
        }

        return received;
    }

    Event events ( )
    {
        return Event.Read;
    }

    public void init ( )
    {
        
    }
}
