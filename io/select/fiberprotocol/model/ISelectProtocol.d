module ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import ocean.io.select.model.ISelectClient;

private import ocean.core.Array: copy, concat;

private import tango.core.Thread : Fiber;

private import TangoException = tango.core.Exception: IOException;

private import tango.stdc.string: strlen;

private import tango.stdc.errno;

debug private import tango.util.log.Trace;

private extern (C) char* strerror_r ( int errnum, char* buf, size_t buflen );

abstract class ISelectProtocol : IAdvancedSelectClient
{
    alias .Fiber Fiber;
    
    public void[] data;
    
    const buffer_size = 0x4000;
    
    protected Fiber fiber;
    
    protected IOException exception;
    
    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit);
        
        this.fiber = fiber;
        
        this.exception = new IOException;
    }

    bool handle ( Event event )
    {
        this.fiber.call();
        return this.fiber.state != this.fiber.State.TERM;
    }

    void transmit ( )
    {
        for (bool more = this.transmit_(); more; more = this.transmit_())
        {
            this.fiber.cede();
        }
    }

    alias transmit opCall;
    
    abstract protected bool transmit_ ( );
    
    static class IOException : TangoException.IOException
    {
        int errnum = 0;
        
        this ( ) {super("");}
        
        typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
        {
            this.errnum = errno;
            
            if (this.errnum)
            {
                char[0x100] buf;
                char* e = strerror_r(errnum, buf.ptr, buf.length);
                
                super.msg.concat(msg, " - ", e[0 .. strlen(e)]);
            }
            else
            {
                super.msg.copy(msg);
            }
            
            super.file.copy(file);
            super.line = line;
            
            return this;
        }
    }
}

