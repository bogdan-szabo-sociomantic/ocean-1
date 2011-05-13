module ocean.io.select.fiberprotocol.SelectReader;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import tango.io.model.IConduit: InputStream;

private import tango.stdc.errno: errno, EAGAIN, EWOULDBLOCK;

debug (Raw) private import tango.util.log.Trace;
debug       private import tango.util.log.Trace;
debug       private import tango.io.Stdout;

class SelectReader : ISelectProtocol
{
    /**************************************************************************

        Callback delegate alias type definitions
    
     **************************************************************************/
    
    alias size_t delegate ( void[] data ) Consumer;

    private void[] data_;
    
    private size_t consumed  = 0,
                   available = 0;
    
    invariant
    {
        assert (available <= this.data_.length);
        assert (consumed  <= this.data_.length);
        assert (consumed  <= available);
    }
    
    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit, fiber);
        
        this.data_ = new void[this.buffer_size];
    }
    
    public void[] data ( )
    {
        return this.data_;
    }
    
    public void[] consumed_data ( )
    {
        return this.data_[0 .. this.consumed];
    }
    
    public void[] remaining_data ( )
    {
        return this.data_[this.consumed .. this.available];
    }
    
    public bool consume ( Consumer consume )
    {
        bool more = false;
        
        do
        {
            size_t consumed = consume(this.remaining_data);
            
            more = consumed > this.remaining_data.length;
            
            this.consumed += (more? this.remaining_data.length : consumed);
        }
        while (more && this.consumed < this.available)
            
        return more;
    }
    
    public typeof (this) reset ( )
    {
        // TODO: this.data_.length = this.buffer_length?
        
        this.consumed  = 0;
        this.available = 0;
        
        return this;
    }
    
    public bool read ( Consumer consumer )
    {
        bool more;
        
        do
        {
            if (this.consumed >= this.available)                                // only this.consumed == this.available possible
            {
                this.receive();
            }
            
            more = this.consume(consumer);
        }
        while (more)
        
        return more;
    }
    
    public size_t receive ( )
    {
        size_t received = this.receive_();
        
        while (!received)
        {
            this.fiber.cede();
            received = this.receive_();
        }
        
        return received;
    }
    
    private size_t receive_ ( )
    out (received)
    {
        assert(received <= data.length, typeof(this).stringof ~ ": received length too high");
    }
    body
    {
        size_t received = (cast (InputStream) super.conduit).read(this.data_[this.available .. $]);
        
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
            }
        }
        
        this.available += received;
        
        return received;
    }

    Event events ( )
    {
        return Event.Read;
    }
    
    private static size_t min ( size_t a, size_t b )
    {
        return (a < b)? a : b;
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
