module ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import ocean.io.select.model.ISelectClient;

private import tango.core.Thread : Fiber;

debug private import tango.util.log.Trace;


class ISelectProtocol : IAdvancedSelectClient
{
    void[] data;
    
    const buffer_size = 16 * 1024;
    
    Fiber fiber;

    this ( ISelectable conduit, Fiber fiber )
    {
        this.fiber = fiber;

        super(conduit);
    }

    bool handle ( Event event )
    {
        Trace.formatln("call state = {}", this.fiber.state);
        this.fiber.call();
        Trace.formatln("call DONE");
        return this.fiber.state != this.fiber.State.TERM;
    }

    void transmit ( )
    {
        bool more;
        do
        {
            more = this.transmit_();
            if ( more ) this.fiber.cede;
        }
        while ( more );
    }

    alias transmit opCall;
    
    abstract protected bool transmit_ ( );

    abstract public void init ( );
}

