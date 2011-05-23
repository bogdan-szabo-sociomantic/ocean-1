/******************************************************************************

    Fiber/coroutine based non-blocking output select client base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Base class for a non-blocking output select client using a fiber/coroutine to
    suspend operation while waiting for the read event and resume on that event.
    
 ******************************************************************************/

module ocean.io.select.fiberprotocol.SelectWriter;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import ocean.io.select.model.ISelectClient;

private import tango.io.model.IConduit: OutputStream;

private import tango.stdc.errno: errno;

class SelectWriter : ISelectProtocol
{
    /**************************************************************************

        Constructor
        
        Params:
            conduit = output conduit (must be an OutputStream)
            fiber   = output reading fiber
            
     **************************************************************************/

    this ( ISelectable conduit, Fiber fiber )
    in
    {
        assert (conduit !is null);
        assert ((cast (OutputStream) conduit) !is null);
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

        Writes data to the output conduit. Whenever the output conduit is not
        ready for writing, the output writing fiber is suspended and continues
        writing on resume.
        
        Returns:
            this instance
            
        Throws:
            IOException on end-of-flow condition:
                - IOWarning if neither error is reported by errno nor socket
                  error
                - IOError if an error is reported by errno or socket error
    
     **************************************************************************/

    typeof (this) send ( void[] data )
    {
        super.repeat(this.send_(data) != 0);
        
        return this;
    }

    /**************************************************************************

        Attempts to write data to the output conduit. The output conduit may or
        may not write all elements of data.
        
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

    private size_t send_ ( void[] data )
    {
        debug (Raw) Trace.formatln("<<< {:X2}", data);
        
        size_t sent = (cast (OutputStream) super.conduit).write(data);
        
        if (sent == OutputStream.Eof)
        {
            super.error_e.checkSocketError("write error", __FILE__, __LINE__);
            
            if (errno)
            {
                throw super.error_e(errno, "write error", __FILE__, __LINE__);
            }
            else
            {
                throw super.warning_e("end of flow whilst writing", __FILE__, __LINE__);
            }
        }
        
        assert (data.length >= sent);
        
        return data.length - sent;
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
