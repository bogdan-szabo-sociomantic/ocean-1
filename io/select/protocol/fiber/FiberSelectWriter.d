/******************************************************************************

    Fiber/coroutine based non-blocking output select client base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Base class for a non-blocking output select client using a fiber/coroutine to
    suspend operation while waiting for the read event and resume on that event.
    
 ******************************************************************************/

module ocean.io.select.protocol.fiber.FiberSelectWriter;

private import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

private import ocean.io.select.model.ISelectClient;

private import tango.io.model.IConduit: OutputStream;

private import tango.stdc.errno: errno;

class FiberSelectWriter : IFiberSelectProtocol
{
    /**************************************************************************

        Constructor
        
        Params:
            conduit = output conduit (must be an OutputStream)
            fiber   = output reading fiber
            
     **************************************************************************/

    this ( ISelectable conduit, Fiber fiber, EpollSelectDispatcher epoll )
    in
    {
        assert (conduit !is null);
        assert ((cast (OutputStream) conduit) !is null);
    }
    body
    {
        super(conduit, fiber, epoll);
    }

    /**************************************************************************

        Mandated by the ISelectClient interface
        
        Returns:
            I/O events to register the conduit of this instance for
    
     **************************************************************************/
    
    Event events ( )
    {
        return Event.Write;
    }
    
    /**************************************************************************

        Data buffer (slices the buffer provided to send())
    
     **************************************************************************/

    private void[] data = null;
    
    /**************************************************************************

        Number of bytes sent so far
    
     **************************************************************************/

    private size_t sent = 0;
    
    /**************************************************************************/
    
    invariant ( )
    {
        assert (this.sent <= this.data.length);
    }
    
    /**************************************************************************

        Writes data to the output conduit. Whenever the output conduit is not
        ready for writing, the output writing fiber is suspended and continues
        writing on resume.
        
        Params:
            data = data to send
        
        Returns:
            this instance
            
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error
    
     **************************************************************************/

    public typeof (this) send ( void[] data )
    in
    {
        assert (!this.data);
    }
    out
    {
        assert (!this.data);
    }
    body
    {
        this.data = data;
        
        scope (exit)
        {
            this.data = null;
            this.sent = 0;
        }
        
        super.transmitLoop();
        
        return this;
    }

    /**************************************************************************

        Attempts to write data to the output conduit. The output conduit may or
        may not write all elements of data.
        
        Params:
            events = events reported for the output conduit
        
        Returns:
            Number of elements (bytes) of the remaining amount of data; that is,
            if the return value is x, data[0 .. $ - x] has been written. 0
            indicates that all data has been written (or data is an empty
            array).
            
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error
    
     **************************************************************************/

    protected bool transmit ( Event events )
    out
    {
        assert (this.sent <= this.data.length);
    }
    body
    {
        debug (Raw) Trace.formatln("<<< {:X2}", this.data);
        
        size_t n = (cast (OutputStream) super.conduit).write(this.data[this.sent .. $]);
        
        if (n == OutputStream.Eof)
        {
            super.error_e.checkSocketError("write error", __FILE__, __LINE__);
            
            if (errno)
            {
                scope (exit) errno = 0;
                
                throw super.error_e(errno, "write error", __FILE__, __LINE__);
            }
            else
            {
                throw super.warning_e("end of flow whilst writing", __FILE__, __LINE__);
            }
        }
        else
        {
            this.sent += n;
        }
        
        return this.sent < this.data.length;
    }
    
    /**************************************************************************

        Class ID string for debugging
    
     **************************************************************************/
    
    debug char[] id ( )
    {
        return typeof (this).stringof;
    }
}
