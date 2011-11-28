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

debug private import ocean.util.log.Trace;

/******************************************************************************/

class FiberSelectWriter : IFiberSelectProtocol
{
    /**************************************************************************

        Delegate to be called when data is sent.

     **************************************************************************/

    public alias void delegate ( void[] ) SentCallback;

    private SentCallback on_sent;

    /**************************************************************************

        Data buffer (slices the buffer provided to send())

     **************************************************************************/

    private ubyte[] data_slice = null;

    /**************************************************************************

        Number of bytes sent so far

     **************************************************************************/

    private size_t sent = 0;

    /**************************************************************************/
    
    invariant ( )
    {
        assert (this.sent <= this.data_slice.length);
    }

    /**************************************************************************

        Constructor
        
        Params:
            conduit = output conduit (must be an OutputStream)
            fiber   = output reading fiber
            
     **************************************************************************/

    this ( ISelectable conduit, SelectFiber fiber )
    in
    {
        assert (conduit !is null, typeof (this).stringof ~ ": conduit is null");
        assert ((cast (OutputStream) conduit) !is null, typeof (this).stringof ~ ": conduit is not an output stream");
    }
    body
    {
        super(conduit, fiber);
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

        Sets a delegate to be called when data is sent.
    
        Params:
            on_sent = delegate to call when data is sent

     **************************************************************************/

    public void sentCallback ( SentCallback on_sent )
    {
        this.on_sent = on_sent;
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
    /*in // FIXME: also causes problems for an as-yet unknown reason
    {
        assert (this.data_slice is null);
    }*/
    /*out // FIXME: DMD bug triggered when overriding method with 'out' contract.
    {
        assert (!this.data);
    }*/
    body
    {
        this.data_slice = cast (ubyte[]) data;
        
        scope (exit)
        {
            this.data_slice = null;
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
            true if all data has been sent
            
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error
    
     **************************************************************************/

    private import tango.stdc.errno: EAGAIN, EWOULDBLOCK;

    protected bool transmit ( Event events )
    out
    {
        assert (this.sent <= this.data_slice.length);
    }
    body
    {
        debug (Raw) Trace.formatln("[{}] <<< {:X2} ({} bytes)", super.conduit.fileHandle, this.data_slice, this.data_slice.length);

        if ( this.on_sent !is null )
        {
            this.on_sent(this.data_slice[this.sent .. $]);
        }

        errno = 0;

        size_t n = (cast (OutputStream) super.conduit).write(this.data_slice[this.sent .. $]);

        if (n == OutputStream.Eof)
        {
            super.error_e.checkSocketError("write error", __FILE__, __LINE__);

            switch (errno)
            {
                case EAGAIN:
                    break;

                case 0:
                    throw super.warning_e("end of flow whilst writing", __FILE__, __LINE__);

                default:
                    throw super.error_e(errno, "write error", __FILE__, __LINE__);
            }
        }
        else
        {
            this.sent += n;
        }

        return this.sent < this.data_slice.length;
    }
    
    /**************************************************************************

        Class ID string for debugging
    
     **************************************************************************/
    
    debug char[] id ( )
    {
        return typeof (this).stringof;
    }
}
