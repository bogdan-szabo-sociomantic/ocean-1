/******************************************************************************

    Fiber/coroutine based non-blocking output select client base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Base class for a non-blocking output select client using a fiber/coroutine to
    suspend operation while waiting for the read event and resume on that event.

    The Linux TCP_CORK feature can be used by setting FiberSelectWriter.cork to
    true. This prevents sending the data passed to send() in partial TCP frames.
    Note that, if TCP_CORK is enabled, pending data may not be sent immediately.
    To force sending pending data, call corkFlush().

    @see http://linux.die.net/man/7/tcp

 ******************************************************************************/

module ocean.io.select.protocol.fiber.FiberSelectWriter;

private import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

private import ocean.io.select.client.model.ISelectClient;

private import ocean.io.device.IODevice: IOutputDevice;

private import tango.stdc.errno: errno, EAGAIN, EWOULDBLOCK, EINTR;

private import tango.stdc.posix.sys.socket: setsockopt;

private import tango.stdc.posix.netinet.in_: IPPROTO_TCP;

extern (C) const int TCP_CORK = 3; /// <linux/tcp.h>


/******************************************************************************/

class FiberSelectWriter : IFiberSelectProtocol
{
    /**************************************************************************

        Set to true to make send() send all data immediately if the TCP_CORK
        feature is enabled. This has the same effect as calling corkFlush()
        after each send().

     **************************************************************************/

    public bool cork_auto_flush = false;

    /**************************************************************************

        Output device

     **************************************************************************/

    public alias .IOutputDevice IOutputDevice;

    private const IOutputDevice output;

    /**************************************************************************

        Data buffer (slices the buffer provided to send())

     **************************************************************************/

    private void[] data_slice = null;

    /**************************************************************************

        Number of bytes sent so far

     **************************************************************************/

    protected size_t sent = 0;

    /**************************************************************************

        true if the TCP_CORK feature is currently enabled or false otherwise

     **************************************************************************/

    private bool cork_ = false;

    /**************************************************************************/

    invariant ( )
    {
        assert (this.sent <= this.data_slice.length);
    }

    /**************************************************************************

        Constructor.

        error_e and warning_e may be the same object if distinguishing between
        error and warning is not required.

        Params:
            output    = output device
            fiber     = output writing fiber
            warning_e = exception to throw if the remote hung up
            error_e   = exception to throw on I/O error

     **************************************************************************/

    public this ( IOutputDevice output, SelectFiber fiber,
           IOWarning warning_e, IOError error_e )
    {
        super(this.output = output, Event.EPOLLOUT, fiber, warning_e, error_e);
    }

    /**************************************************************************

        Constructor

        Uses the conduit, fiber and exceptions from the other
        IFiberSelectProtocol instance. This is useful when this instance shares
        the conduit and fiber with another IFiberSelectProtocol instance, e.g.
        a FiberSelectReader.

        The conduit owned by the other instance must have been downcast from
        IOuputDevice.

        Params:
            other       = other instance of this class

     **************************************************************************/

    public this ( typeof (super) other )
    {
        super(other, Event.EPOLLOUT);

        this.output = cast (IOutputDevice) this.conduit;

        assert (this.output !is null, typeof (this).stringof ~ ": the conduit of "
                "the other " ~ typeof (super).stringof ~ " instance must be a "
                ~ IOutputDevice.stringof);
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
            IOException if the connection is closed or broken:
                - IOWarning if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

     **************************************************************************/

    public typeof (this) send ( void[] data )
/*    in // FIXME: causes an unknown (i.e. uninvestigated) problem, for example in the queue monitor
    {
        assert (this.data_slice is null);
    }*/
    /*out // FIXME: DMD bug triggered when overriding method with 'out' contract.
    {
        assert (!this.data);
    }*/
    body
    {
        if (data.length)
        {
            this.data_slice = data;

            if (this.cork_)
            {
                this.cork = true;
            }

            try
            {
                super.transmitLoop();
            }
            finally
            {
                if (this.cork_ && this.cork_auto_flush)
                {
                    this.cork_ = this.setCork(false);
                }

                this.data_slice = null;
                this.sent = 0;
            }
        }

        return this;
    }

    /**************************************************************************

        Enables or disables the TCP_CORK feature.

        Note that, if is enabled, not all data passed to send() may be sent
        immediately; to force sending pending data, call corkFlush() after
        send() or set cork_auto_flush to true before calling send().

        If enabled is false but the TCP_CORK is currently enabled, pending data
        will be sent now.

        If send() or corkFlush() encounter an error using the TCP_CORK feature,
        it is disabled automatically.

        Params:
            enabled = true: enable the TCP_CORK feature; false: disable it.

        Returns:
            true if successfully enabled or false if either disabled or on
            failure enabling TCP_CORK.

     **************************************************************************/

    public bool cork ( bool enabled )
    {
        if (this.cork_)
        {
            if (!enabled)
            {
                this.setCork(this.cork_ = false);
            }
        }
        else
        {
            if (enabled)
            {
                this.cork_ = this.setCork(true);
            }
        }

        return this.cork_;
    }

    /**************************************************************************

        Tells whether the TCP_CORK feature is currently enabled.

        Returns:
            true if the TCP_CORK feature is currently enabled or false
            otherwise.

     **************************************************************************/

    public bool cork ( )
    {
        return this.cork_;
    }

    /**************************************************************************

        Sends all pending data immediately if the TCP_CORK feature is currently
        enabled.

        Returns:
            if the TCP_CORK feature is currently enabled and data have been
            sent or false if disabled or an error was reported using TCP_CORK.
            On error the TCP_CORK feature is automatically disabled.

     **************************************************************************/

    public bool corkFlush ( )
    {
        return this.cork_? this.cork_ = this.setCork(false) : false;
    }

    /**************************************************************************

        Sends all pending data immediately.
        May be overridden by a subclass; calls corkFlush() by default.

        Returns:
            this instance.

     **************************************************************************/

    public typeof (this) flush ( )
    {
        this.corkFlush();

        return this;
    }

    /**************************************************************************

        Clears any pending data in the buffer.

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) reset ( )
    {
        this.corkFlush();

        return this;
    }

    /**************************************************************************

        Attempts to write data to the output conduit. The output conduit may or
        may not write all elements of data.

        Params:
            events = events reported for the output conduit

        Returns:
            true if all data has been sent or false to try again.

        Throws:
            IOException if the connection is closed or broken:
                - IOWarning if the remote hung up,
                - IOError (IOWarning subclass) on I/O error.

     **************************************************************************/

    protected bool transmit ( Event events )
    out
    {
        assert (this);
    }
    body
    {
        debug (Raw) Trace.formatln("[{}] Write {:X2} ({} bytes)",
            super.conduit.fileHandle, this.data_slice, this.data_slice.length);

        if (this.sent < this.data_slice.length)
        {
            .errno = 0;

            output.ssize_t n = this.output.write(this.data_slice[this.sent .. $]);

            if (n >= 0)
            {
                this.sent += n;
            }
            else
            {
                this.error_e.checkDeviceError("write error", __FILE__, __LINE__);

                this.warning_e.assertEx(!(events & events.EPOLLHUP), "connection hung up", __FILE__, __LINE__);

                int errnum = .errno;

                switch (errnum)
                {
                    default:
                        throw this.error_e(errnum, "write error", __FILE__, __LINE__);

                    case EINTR, EAGAIN:
                        static if ( EAGAIN != EWOULDBLOCK )
                        {
                            case EWOULDBLOCK:
                        }
                }
            }
        }

        return this.sent < this.data_slice.length;
    }


    /**************************************************************************

        Sets the TCP_CORK option. Disabling (enable = 0) sends all pending data.

        Params:
            enable = 0 disables TCP_CORK and flushes if previously enabled, a
                     different value enables TCP_CORK.

         Returns:
             true on success or false if setsockopt reports error. On error
             errno is set accordingly.

     **************************************************************************/

    private bool setCork ( int enable )
    {
        return !.setsockopt(super.conduit.fileHandle, .IPPROTO_TCP, .TCP_CORK,
                            &enable, enable.sizeof);
    }
}
