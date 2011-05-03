module ocean.io.select.fiberprotocol.SelectWriter;

private import ocean.core.Exception;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import tango.io.model.IConduit;
private import tango.core.Exception;

private import tango.core.Thread : Fiber;

debug ( Raw ) private import tango.util.log.Trace;


class SelectWriter : ISelectProtocol
{
    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit, fiber);
    }

    protected bool transmit_ ( )
    {
        debug (Raw) Trace.formatln("<<< {:X2}", data);

        size_t sent = (cast(OutputStream)conduit).write(data);

        assertEx!(IOException)(sent != OutputStream.Eof, typeof(this).stringof ~ ": end of flow whilst writing");

        return sent < super.data.length;
    }

    Event events ( )
    {
        return Event.Write;
    }
}

