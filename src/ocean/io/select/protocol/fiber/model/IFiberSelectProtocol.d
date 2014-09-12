/******************************************************************************

    Fiber/coroutine based non-blocking I/O select client base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt, Gavin Norman

    Base class for a non-blocking I/O select client using a fiber/coroutine to
    suspend operation while waiting for the I/O event and resume on that event.

 ******************************************************************************/

module ocean.io.select.protocol.fiber.model.IFiberSelectProtocol;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.core.MessageFiber;

private import ocean.io.select.client.model.IFiberSelectClient;

private import ocean.io.select.fiber.SelectFiber;

private import ocean.io.select.protocol.generic.ErrnoIOException: IOError, IOWarning;

debug ( SelectFiber ) private import tango.util.log.Trace;


/******************************************************************************/

abstract class IFiberSelectProtocol : IFiberSelectClient
{
    /***************************************************************************

        Token used when suspending / resuming fiber.

    ***************************************************************************/

    static private MessageFiber.Token IOReady;

    /***************************************************************************

        Static ctor. Initialises fiber token.

    ***************************************************************************/

    static this ( )
    {
        IOReady = MessageFiber.Token("io_ready");
    }

    /**************************************************************************

        Local aliases

     **************************************************************************/

    protected alias .SelectFiber            SelectFiber;

    public alias .IOWarning IOWarning;
    public alias .IOError   IOError;

    /**************************************************************************

        I/O device

     **************************************************************************/

    protected const ISelectable conduit;

    /**************************************************************************

        Events to register the I/O device for.

     **************************************************************************/

    protected const Event events_;

    /**************************************************************************

        IOWarning exception instance

     **************************************************************************/

    protected const IOWarning warning_e;

    /**************************************************************************

        IOError exception instance

     **************************************************************************/

    protected const IOError error_e;

    /**************************************************************************

        Events reported to handle()

     **************************************************************************/

    private Event events_reported;

    /**************************************************************************

        Constructor

        Params:
            conduit   = I/O device
            events    = the epoll events to register the device for
            fiber     = fiber to use to suspend and resume operation

     **************************************************************************/

    protected this ( ISelectable conduit, Event events, SelectFiber fiber )
    {
        this(conduit, events, fiber, new IOWarning(conduit), new IOError(conduit));
    }

    /**************************************************************************

        Constructor

        Note: If distinguishing between warnings and errors is not desired or
              required, pass the same object for warning_e and error_e.


        Params:
            conduit   = I/O device
            events    = the epoll events to register the device for
            fiber     = fiber to use to suspend and resume operation
            warning_e = Exception instance to throw for warnings
            error_e   = Exception instance to throw on errors and to query
                        device specific error codes if possible

     **************************************************************************/

    protected this ( ISelectable conduit, Event events, SelectFiber fiber,
                     IOWarning warning_e, IOError error_e )
    in
    {
        assert (conduit !is null);
        assert (warning_e !is null);
        assert (error_e !is null);
    }
    body
    {
        super(fiber);
        this.conduit   = conduit;
        this.events_   = events;
        this.warning_e = warning_e;
        this.error_e   = error_e;
    }

    /**************************************************************************

        Constructor

        Uses the conduit, fiber and exceptions from the other instance. This is
        useful when instances of several subclasses share the same conduit and
        fiber.

        Params:
            other  = other instance of this class
            events    = the epoll events to register the device for

     **************************************************************************/

    protected this ( typeof (this) other, Event events )
    {
        this(other.conduit, events, other.fiber, other.warning_e, other.error_e);
    }

    /**************************************************************************

        Returns:
            the I/O device file handle.

     **************************************************************************/

    public Handle fileHandle ( )
    {
        return this.conduit.fileHandle();
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
            current socket error code, if available, or 0 otherwise.

     **************************************************************************/

    public override int error_code ( )
    {
        return this.error_e.error_code;
    }

    /**************************************************************************

        Resumes the fiber coroutine and handle the events reported for the
        conduit. The fiber must be suspended (HOLD state).

        Note that the fiber coroutine keeps going after this method has finished
        if there is another instance of this class which shares the fiber with
        this instance and is invoked in the coroutine after this instance has
        done its job.

        Returns:
            false if the fiber is finished or true if it keeps going

        Throws:
            IOException on I/O error

     **************************************************************************/

    final protected bool handle ( Event events )
    in
    {
        assert (this.fiber.waiting);
    }
    body
    {
        this.events_reported = events;

        debug ( SelectFiber ) Trace.formatln("{}.handle: fd {} fiber resumed",
                typeof(this).stringof, this.conduit.fileHandle);
        SelectFiber.Message message = this.fiber.resume(IOReady, this); // SmartUnion
        debug ( SelectFiber ) Trace.formatln("{}.handle: fd {} fiber yielded, message type = {}",
                typeof(this).stringof, this.conduit.fileHandle, message.active);

        return (message.active == message.active.num)? message.num != 0 : false;
    }

    /**************************************************************************

        Registers this instance in the select dispatcher and repeatedly calls
        transmit() until the transmission is finished.

        Throws:
            IOException on I/O error, KillableFiber.KilledException if the
            fiber was killed.

        In:
            The fiber must be running.

     **************************************************************************/

    protected void transmitLoop ( )
    in
    {
        assert (this.fiber.running);
    }
    body
    {
        // The reported events are reset at this point to avoid using the events
        // set by a previous run of this method.

        try for (bool more = this.transmit(this.events_reported = this.events_reported.init);
                      more;
                      more = this.transmit(this.events_reported))
        {
            super.fiber.register(this);

            // Calling suspend() triggers an epoll wait, which will in turn call
            // handle_() (above) when an event fires for this client. handle_()
            // sets this.events_reported to the event reported by epoll.
            super.fiber.suspend(IOReady, this, fiber.Message(true));

            this.error_e.assertEx(!(this.events_reported & Event.EPOLLERR), "I/O error", __FILE__, __LINE__);
        }
        catch (SelectFiber.KilledException e)
        {
            throw e;
        }
        catch (Exception e)
        {
            if (super.fiber.isRegistered(this))
            {
                debug ( SelectFiber) Trace.formatln("{}.transmitLoop: suspending fd {} fiber ({} @ {}:{})",
                    typeof(this).stringof, this.conduit.fileHandle, e.msg, e.file, e.line);

                // Exceptions thrown by transmit() or in the case of the Error
                // event are passed to the fiber resume() to be rethrown in
                // handle_(), above.
                super.fiber.suspend(IOReady, e);

                debug ( SelectFiber) Trace.formatln("{}.transmitLoop: resumed fd {} fiber, rethrowing ({} @ {}:{})",
                    typeof(this).stringof, this.conduit.fileHandle, e.msg, e.file, e.line);
            }

            throw e;
        }
    }

    /**************************************************************************

        Reads/writes data from/to super.conduit for which events have been
        reported.

        Params:
            events = events reported for super.conduit

        Returns:
            true to be invoked again (after an epoll wait) or false if finished

     **************************************************************************/

    abstract protected bool transmit ( Event events );
}
