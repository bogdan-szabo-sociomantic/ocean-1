module ocean.io.select.fiberprotocol.SelectWriter;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import tango.io.model.IConduit: OutputStream;
private import ocean.core.Exception: assertEx;

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

        assertEx(sent != OutputStream.Eof, super.exception("end of flow whilst writing", __FILE__, __LINE__));

        return sent < super.data.length;
    }

    Event events ( )
    {
        return Event.Write;
    }
}

