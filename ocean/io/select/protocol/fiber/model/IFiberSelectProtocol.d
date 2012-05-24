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

    protected alias .SelectFiber            SelectFiber;
    protected alias .EpollSelectDispatcher  EpollSelectDispatcher;
    
    public alias .IOWarning IOWarning;
    public alias .IOError   IOError;
    
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
    
        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)
    
     **************************************************************************/

    protected override void dispose ( )
    {
        super.dispose();
        
        delete this.warning_e;
        delete this.error_e;
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
        // The reported events are reset at this point to avoid using the
        // events set by a previous run of this method.
        
        try for (bool more = this.transmit(this.events_reported = this.events_reported.init);
                      more;
                      more = this.transmit(this.events_reported))
        {
            super.fiber.register(this);
            
            // Calling suspend() triggers an epoll wait, which will in
            // turn call handle_() (above) when an event fires for this
            // client. handle_() sets this.events_reported to the event
            // reported by epoll.
            super.fiber.suspend(fiber.Message(true));

            this.error_e.assertEx(!(this.events_reported & Event.Error), "socket error", __FILE__, __LINE__);
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

                // Exceptions thrown by transmit() or in the case of the Error event
                // are passed to the fiber resume() to be rethrown in handle_(),
                // above.
                super.fiber.suspend(e);

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
            true to be invoked again or false if finished
        
     **************************************************************************/

    abstract protected bool transmit ( Event events );
}

