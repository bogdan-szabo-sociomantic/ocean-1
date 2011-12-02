/******************************************************************************

    Fiber/coroutine based buffered non-blocking output select client

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman
    
 ******************************************************************************/

module ocean.io.select.protocol.fiber.BufferedFiberSelectWriter;

private import ocean.io.select.protocol.fiber.FiberSelectWriter;

private import ocean.core.AppendBuffer;

/******************************************************************************/

class BufferedFiberSelectWriter : FiberSelectWriter
{
    /**************************************************************************

        Default buffer size (64 kB)
            
     **************************************************************************/

    public const default_buffer_size = 0x1_0000;
    
    /**************************************************************************

        AppendBuffer instance
            
     **************************************************************************/

    private const AppendBuffer!(ubyte) buffer;
    
    /**************************************************************************

        Constructor
        
        Params:
            conduit = output conduit (must be an OutputStream)
            fiber   = output reading fiber
            size    = buffer size
            
        In:
            The buffer size must not be 0.

     **************************************************************************/

    public this ( ISelectable conduit, SelectFiber fiber, size_t size = default_buffer_size )
    in
    {
        assert (size, typeof (this).stringof ~ ": initial buffer size is 0");
    }
    body
    {
        super(conduit, fiber);
        this.buffer = new AppendBuffer!(ubyte)(size, true);
    }
    
    /**************************************************************************

        Returns:
            current buffer size
            
     **************************************************************************/

    public size_t buffer_size ( )
    {
        return this.buffer.capacity;
    }
    
    
    /**************************************************************************
    
        Flushes the buffer.
        
        Returns:
            this instance.
            
     **************************************************************************/

    public size_t flush ( )
    {
        scope (success)
        {
            super.send(this.buffer.dump());
        }
        
        return this.buffer.length;
    }
    
    /**************************************************************************
    
        Sets the buffer size to s. If there are currently more than s bytes of
        data in the buffer, flush() is called before setting the size. 
        
        Params:
            s = new buffer size
        
        Returns:
            new buffer size
            
        In:
            The new buffer size must not be 0.
            
     **************************************************************************/

    public size_t buffer_size ( size_t s )
    in
    {
        assert (s, typeof (this).stringof ~ ".buffer_size: 0 specified");
    }
    out (n)
    {
        assert (n == s);
    }
    body
    {
        if (s < this.buffer.length)
        {
            this.flush();
        }
        
        return this.buffer.capacity = s;
    }
    
    /**************************************************************************
    
        Sends data_.
        
        Params:
            data_: data to send
        
        Returns:
            this instance.
            
     **************************************************************************/

    public override typeof (this) send ( void[] data )
    {
        if (data.length < this.buffer.capacity)
        {
            void[] dst = this.buffer.extend(data.length);
            
            dst[] = data[0 .. dst.length];
            
            void[] left = data[dst.length .. $];
            
            if (left.length || this.buffer.length == this.buffer.capacity)
            {
                this.flush();
            }
            
            if (left.length)
            {
                this.buffer ~= cast (ubyte[]) left;
            }
        }
        else
        {
            this.flush();
            super.send(data);
        }
        
        return this;
    }
}
