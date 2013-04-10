module ocean.io.select.protocol.SelectReader;

import ocean.io.select.model.ISelectClient;
import ocean.io.device.IODevice;
import ocean.io.select.protocol.generic.ErrnoIOException;
import tango.sys.linux.consts.errno;
import tango.stdc.errno;

class SelectReader : IAdvancedSelectClient
{
    private IInputDevice input;

    private ubyte[] buffer;

    private void delegate ( void[] data ) reader;

    /**************************************************************************

        IOWarning exception instance

     **************************************************************************/

    protected const IOWarning warning_e;

    /**************************************************************************

        IOError exception instance

     **************************************************************************/

    protected const IOError error_e;

    private Event events_ = Event.EPOLLIN | Event.EPOLLRDHUP;

    public this ( IInputDevice input, size_t buffer_size, IOWarning warning_e = null , IOError error_e = null)
    {
        this.input = input;
        this.buffer = new ubyte[buffer_size];

        this.warning_e =  warning_e is null ? new IOWarning(input) : warning_e;
        this.error_e   =  error_e   is null ? new IOError(input)   : error_e;
    }

    /**************************************************************************

        Returns:
            the events to register the I/O device for.

     **************************************************************************/

    public Event events ( )
    {
        return this.events_;
    }

    /**************************************************************************

        Returns:
            the I/O device file handle.

     **************************************************************************/

    public Handle fileHandle ( )
    {
        return this.input.fileHandle();
    }

    public void read ( void delegate ( void[] data ) dg )
    {
        this.reader = dg;

        this.read(Event.None);
    }

    private void read ( Event events )
    {
        .errno = 0;

        input.ssize_t n = this.input.read(this.buffer);

        if (n <= 0)
        {
             // EOF or error: Check for socket error and hung-up event first.

            this.error_e.checkDeviceError(n? "read error" : "end of flow whilst reading", __FILE__, __LINE__);

            this.warning_e.assertEx(!(events & events.EPOLLRDHUP), "connection hung up on read", __FILE__, __LINE__);
            this.warning_e.assertEx(!(events & events.EPOLLHUP),   "connection hung up", __FILE__, __LINE__);

            if (n)
            {
                // read() error and no socket error or hung-up event: Check
                // errno. Carry on if there are just currently no data available
                // (EAGAIN/EWOULDBLOCK/EINTR) or throw error otherwise.

                int errnum = .errno;

                switch (errnum)
                {
                    default:
                        throw this.error_e(errnum, "read error", __FILE__, __LINE__);

                    case EINTR, EAGAIN:
                        static if ( EAGAIN != EWOULDBLOCK )
                        {
                            case EWOULDBLOCK:
                        }

                        // EAGAIN/EWOULDBLOCK: currently no data available.
                        // EINTR: read() was interrupted by a signal before data
                        //        became available.

                        n = 0;
                }
            }
            else
            {
                // EOF and no socket error or hung-up event: Throw EOF warning.

                throw this.warning_e("end of flow whilst reading", __FILE__, __LINE__);
            }
        }
        else
        {
            debug (Raw) Trace.formatln("[{}] Read  {:X2} ({} bytes)",
                this.fileHandle,
                this.buffer[0 .. n], n);
        }

        assert (n >= 0);

        if ( n > 0 )
        {
            this.reader(this.buffer[0 .. n]);
        }
    }

    final protected bool handle ( Event events )
    {
        this.read(events);
        debug ( SelectFiber ) Trace.formatln("{}.handle: fd {} read() called",
                typeof(this).stringof, this.fileHandle);

        return true;
    }
}

