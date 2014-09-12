/*******************************************************************************

    Fiberless SelectReader

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        May 2013: Initial release
                    July 2013: Added comments

    authors:        Mathias Baumann

*******************************************************************************/

module ocean.io.select.protocol.SelectReader;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.io.select.client.model.ISelectClient;
import ocean.io.device.IODevice;
import ocean.io.select.protocol.generic.ErrnoIOException;

import tango.sys.linux.consts.errno;
import tango.stdc.errno;

debug (Raw)         private import tango.util.log.Trace;
debug (SelectFiber) private import tango.util.log.Trace;

/*******************************************************************************

    SelectReader without Fiber

    This is useful for when you want to read when there is something to read but
    you don't want to block/wait/suspend your fiber when there is nothing.

*******************************************************************************/

class SelectReader : IAdvancedSelectClient
{
    /***************************************************************************

        Reader device

    ***************************************************************************/

    private IInputDevice input;

    /***************************************************************************

        Reader buffer

    ***************************************************************************/

    private ubyte[] buffer;

    /***************************************************************************

        Reader delegate, will be called with new data

    ***************************************************************************/

    private void delegate ( void[] data ) reader;

    /**************************************************************************

        IOWarning exception instance

     **************************************************************************/

    protected const IOWarning warning_e;

    /**************************************************************************

        IOError exception instance

     **************************************************************************/

    protected const IOError error_e;

    /***************************************************************************

        Events to we are interested in

    ***************************************************************************/

    private Event events_ = Event.EPOLLIN | Event.EPOLLRDHUP;

    /***************************************************************************

        Constructor

        Params:
            input       = input device to use
            buffer_size = buffer size to use
            warning_e   = instance of a reusable exception to use, will be
                          allocated if null
            error_e     = instance of a reusable exception to use, will be
                          allocated if null

    ***************************************************************************/

    public this ( IInputDevice input, size_t buffer_size, IOWarning warning_e =
                  null , IOError error_e = null)
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


    /***************************************************************************

        Feed delegate with data that was read.

        Params:
            dg = delegate to call with new data

    ***************************************************************************/

    public void read ( void delegate ( void[] data ) dg )
    {
        this.reader = dg;

        this.read(Event.None);
    }


    /***************************************************************************

        Read data if events don't indicate end of connection

        Params:
            events = events

    ***************************************************************************/

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


    /***************************************************************************

        Handle socket events

        Params:
            events = events to handle

        Returns:
            true, so it stays registered

    ***************************************************************************/

    final protected bool handle ( Event events )
    {
        this.read(events);
        debug ( SelectFiber ) Trace.formatln("{}.handle: fd {} read() called",
                typeof(this).stringof, this.fileHandle);

        return true;
    }
}

