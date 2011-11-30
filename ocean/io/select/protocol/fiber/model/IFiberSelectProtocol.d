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

private import ocean.io.select.model.IFiberSelectClient;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.fiber.SelectFiber;

private import ocean.io.select.protocol.generic.ErrnoIOException: IOError, IOWarning;

debug private import ocean.util.log.Trace;

/******************************************************************************/

abstract class IFiberSelectProtocol : IFiberSelectClient
{
    /**************************************************************************

        Local aliases

     **************************************************************************/

    protected alias .SelectFiber SelectFiber;
    protected alias .EpollSelectDispatcher  EpollSelectDispatcher;

    public alias .IOWarning IOWarning;
    public alias .IOError IOError;

    /**************************************************************************

        Default I/O data buffer size (if a buffer is actually involved; this
        depends on the subclass implementation)
    
     **************************************************************************/
    
    const buffer_size = 0x4000;

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
             conduit = I/O device
             fiber   = fiber to use to suspend and resume operation
    
     **************************************************************************/

    this ( ISelectable conduit, SelectFiber fiber )
    {
        super(conduit, fiber);
        this.warning_e = new IOWarning(this);
        this.error_e   = new IOError(this);
    }

    /**************************************************************************

        Causes a running fiber to suspend and the conduit to be registered with
        epoll.

     **************************************************************************/

    public void cede ( )
    {
        this.handleErrors({ this.cede_(); });
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

        debug ( SelectFiber) Trace.formatln("{}.handle: fd {} fiber resumed",
                typeof(this).stringof, this.conduit.fileHandle);

        SelectFiber.Message message = this.fiber.resume(); // SmartUnion

        debug ( SelectFiber) Trace.formatln("{}.handle: fd {} fiber yielded, message type = {}",
                typeof(this).stringof, this.conduit.fileHandle, message.active);

        return (message.active == message.active.num)? message.num != 0 : false;
    }

    /**************************************************************************

        Registers this instance in the select dispatcher and repeatedly calls
        transmit() until the transmission is finished. Each call to transmit()
        is followed by a calle to cede_(), suspending the fiber until the
        conduit fires again in epoll.

     **************************************************************************/

    final protected void transmitLoop ( )
    {
        // The reported events are reset at this point to avoid using the
        // events set by a previous run of this method.
        this.events_reported = this.events_reported.init;

        this.handleErrors({
            for (bool more = this.transmit(this.events_reported);
                      more;
                      more = this.transmit(this.events_reported))
            {
                this.cede_();
            }
        });
    }

    /**************************************************************************

        Reads/writes data from/to super.conduit for which events have been
        reported.
        
        Params:
            events = events reported for super.conduit
            
        Returns:
            true to be invoked again or false if finished
        
     **************************************************************************/

    abstract protected bool transmit ( Event events );

    /**************************************************************************

        Suspends the fiber until an event fires for the conduit in epoll. When
        the fiber is resumed (by the handle() method), the reported event from
        epoll is checked to see if an error occurred.

        Throws:
            this.error_e upon occurrence of an Error event being reported for
            the conduit in epoll

     **************************************************************************/

    private void cede_ ( )
    {
        super.fiber.register(this);

        // Calling suspend() triggers an epoll wait, which will in
        // turn call handle_() (above) when an event fires for this
        // client. handle_() sets this.events_reported to the event
        // reported by epoll.
        super.fiber.suspend(fiber.Message(true));

        this.error_e.assertEx(!(this.events_reported & Event.Error), "socket error", __FILE__, __LINE__);
    }

    /**************************************************************************

        Invokes the passed delegate and handles any exceptions which occur.

        Params:
            action = delegate to invoke

        Throws:
            any exceptions caught while invoking action are rethrown

        In:
            * Action must not be null
            * The fiber must be running.

     **************************************************************************/

    private void handleErrors ( void delegate ( ) action )
    in
    {
        assert(action !is null, typeof(this).stringof ~ ".transmitLoop_: action delegate must be non-null");
        assert(this.fiber.running);
    }
    body
    {
        try
        {
            action();
        }
        catch (SelectFiber.KilledException e)
        {
            throw e;
        }
        catch (Exception e)
        {
            if (super.fiber.isRegistered(this))
            {
                debug ( SelectFiber ) Trace.formatln("{}.transmitLoop: suspending fd {} fiber ({} @ {}:{})",
                    typeof(this).stringof, this.conduit.fileHandle, e.msg, e.file, e.line);

                // Exceptions thrown by transmit() or in the case of the Error event
                // are passed to the fiber resume() to be rethrown in handle_(),
                // above.
                super.fiber.suspend(e);

                debug ( SelectFiber ) Trace.formatln("{}.transmitLoop: resumed fd {} fiber, rethrowing ({} @ {}:{})",
                    typeof(this).stringof, this.conduit.fileHandle, e.msg, e.file, e.line);
            }

            throw e;
        }
    }
}

