module ocean.io.select.fiberprotocol.SelectWriter;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import ocean.io.select.model.ISelectClient;

private import tango.io.model.IConduit: OutputStream;

debug private import tango.util.log.Trace;

class SelectWriter : ISelectProtocol
{
    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit, fiber);
    }

    Event events ( )
    {
        return Event.Write;
    }
    
    void write ( void[] data )
    {
        for (bool more = this.send(data); more; more = this.send(data))
        {
            this.fiber.cede();
        }
    }

    protected bool send ( void[] data )
    {
        debug (Raw) Trace.formatln("<<< {:X2}", data);

        size_t sent = (cast(OutputStream)conduit).write(data);

        super.exception.assertEx(sent != OutputStream.Eof, "end of flow whilst writing", __FILE__, __LINE__);
        
        return sent < data.length;
    }
    
    /**************************************************************************

        Class ID string for debugging
    
     **************************************************************************/
    
    debug (ISelectClient)
    {
        const ClassId = typeof (this).stringof;
        
        public char[] id ( )
        {
            return this.ClassId;
        }
    }
}

