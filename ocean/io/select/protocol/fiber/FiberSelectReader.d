/******************************************************************************

    Fiber/coroutine based non-blocking input select client base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Base class for a non-blocking input select client using a fiber/coroutine to
    suspend operation while waiting for the read event and resume on that event.
    Provides a stream-like interface with consumer delegate invocation to
    receive and consume data from the input until the consumer indicates it has
    finished.
    
 ******************************************************************************/

module ocean.io.select.protocol.fiber.FiberSelectReader;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

private import ocean.io.select.protocol.generic.ReadConduit;

private import tango.io.model.IConduit: InputStream;

private import tango.math.Math : min;

debug private import ocean.util.log.Trace;

/******************************************************************************/

class FiberSelectReader : IFiberSelectProtocol
{
    /**************************************************************************

        Default input buffer size (16 kB).

     **************************************************************************/

    public const size_t default_buffer_size = 0x4000;
    
    /**************************************************************************

        Delegate to be called when data is received.

     **************************************************************************/

    public alias void delegate ( void[] ) ReceivedCallback;

    private ReceivedCallback on_received;

    /**************************************************************************

        Consumer callback delegate type
        
        Params:
            data = data to consume
            
        Returns:
            - if finished, a value of [0, data.length] reflecting the number of
              elements (bytes) consumed or
            - a value greater than data.length if more data is required.
    
     **************************************************************************/
    
    alias size_t delegate ( void[] data ) Consumer;

    /**************************************************************************

        Data buffer
    
     **************************************************************************/

    private void[] data;
    
    /**************************************************************************

        Conduit reader, handles Eof, EAGAIN and socket errors.
    
     **************************************************************************/

    private const ReadConduit           readConduit;
    
    /**************************************************************************

        End index of available and consumed data.
        
        Available data is data received by receive() or read() and not yet
        consumed by the consumer delegate passed to consume() or read().
        Consumed data is data received by receive() or read() and already
        consumed by the consumer delegate passed to consume() or read().
    
     **************************************************************************/

    private size_t available = 0,
                   consumed  = 0;
    
    /**************************************************************************

        Invariant to assure consumed/available are in correct order and range 
    
     **************************************************************************/
    
    invariant
    {
        assert (available <= this.data.length);
        assert (consumed  <= this.data.length);
        assert (consumed  <= available);
    }
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit     = input conduit (must be an InputStream)
            fiber       = input reading fiber
            buffer_size = input buffer size
            
     **************************************************************************/

    this ( ISelectable conduit, SelectFiber fiber, size_t buffer_size = this.default_buffer_size )
    in
    {
        assert ((cast (InputStream) conduit) !is null);
    }
    body
    {
        super(conduit, fiber);
        this.data = new ubyte[buffer_size];
        this.readConduit = new ReadConduit(cast (InputStream) conduit, super.warning_e, super.error_e);
    }
    
    /**************************************************************************
    
        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)
    
     **************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        
        delete this.data;
        delete this.readConduit;
    }
    
    /**************************************************************************

        Mandated by the ISelectClient interface
        
        Returns:
            I/O events to register the conduit of this instance for
    
     **************************************************************************/
    
    Event events ( )
    {
        return Event.Read | Event.ReadHangup;
    }

    /**************************************************************************

        Resets the amount of consumed/available data to 0.
        
        Returns:
            this instance
            
     **************************************************************************/

    public typeof (this) reset ( )
    {
        this.consumed  = 0;
        this.available = 0;
        
        return this;
    }
    
    /**************************************************************************

        Returns:
            data in buffer available and consumed so far
            
     **************************************************************************/

    public void[] consumed_data ( )
    {
        return this.data[0 .. this.consumed];
    }
    
    /**************************************************************************

        Returns:
            data in buffer available but not consumed so far
            
     **************************************************************************/

    public void[] remaining_data ( )
    {
        return this.data[this.consumed .. this.available];
    }
    
    /**************************************************************************

        Sets a delegate to be called when data is received.
    
        Params:
            on_received = delegate to call when data is received

     **************************************************************************/

    public void receivedCallback ( ReceivedCallback on_received )
    {
        this.on_received = on_received;
    }

    /**************************************************************************

        Invokes consume to consume the available data until consume indicates to
        be finished or all available data is consumed.
        
        Params:
            consume = consumer callback delegate
            
        Returns:
            - true if all available data in buffer has been consumed and consume
              indicated that it requires more or
            - false if consume indicated to be finished. 
            
     **************************************************************************/

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
    
    /**************************************************************************

        Reads data from the input conduit and appends them to the data buffer,
        waiting for data to be read from the input conduit if 
        
        If no data is available from the input conduit, the input reading fiber
        is suspended and continues reading on resume.
        
        Returns:
            number of bytes read
        
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error
        
     **************************************************************************/

    public size_t receive ( )
    {
        if (this.available >= this.data.length)
        {
            this.reset();
        }
        
        size_t available_before = this.available;
        
        super.transmitLoop();
        
        return this.available - available_before;
    }
    
    /**************************************************************************

        Reads data from the input conduit, appends them to the data buffer and
        invokes consume with the available data until consume indicates to be
        finished. Whenever no data is available from the input conduit, the
        input reading fiber is suspended and continues reading on resume.
        
        Params:
            consume = consumer callback delegate
            
        Returns:
            this instance
            
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error

     **************************************************************************/

    public typeof (this) read ( Consumer consume )
    {
        bool more;

        do
        {
            if (this.consumed >= this.available)                                // only this.consumed == this.available possible
            {
                this.receive();
            }

            more = this.consume(consume);
        }
        while (more)

        return this;
    }

    /**************************************************************************

        Reads data from the input conduit and appends them to the data buffer.
        
        Returns:
            number of bytes read
        
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error

     **************************************************************************/

    protected bool transmit ( Event events )
    in
    {
        assert (this.available < this.data.length, "requested to receive nothing");
    }
    out (received)
    {
        assert (received <= data.length, "received length too high");
    }
    body
    {
        size_t received = this.readConduit(this.data[this.available .. $], events);

        if ( this.on_received !is null )
        {
            this.on_received(this.data[this.available .. this.available + received]);
        }

        debug (Raw) Trace.formatln("[{}] >>> {:X2} ({} bytes)", super.conduit.fileHandle, this.data[this.available .. this.available + received], received);

        this.available += received;
        
        return !received;
    }

    /**************************************************************************

        Class ID string for debugging
    
     **************************************************************************/
    
    public char[] id ( )
    {
        return typeof (this).stringof;
    }
}

