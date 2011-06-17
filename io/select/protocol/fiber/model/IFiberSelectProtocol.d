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

private import ocean.io.select.protocol.model.ISelectProtocol;

private import ocean.io.select.EpollSelectDispatcher;

private import ocean.io.select.protocol.fiber.model.KillableFiber;

/******************************************************************************/

abstract class IFiberSelectProtocol : ISelectProtocol
{
    protected alias .KillableFiber                 Fiber;
    protected alias .EpollSelectDispatcher EpollSelectDispatcher;
    
    /**************************************************************************

        Fiber (may be shared across instances of this class)
    
     **************************************************************************/

    private Fiber fiber;
    
    /**************************************************************************

        Epoll select dispatcher instance
    
     **************************************************************************/

    private EpollSelectDispatcher epoll;
    
    /**************************************************************************

        Events reported to handle()
    
     **************************************************************************/

    private Event events_reported;
    
    /**************************************************************************

        true: handle() needs to invoked again; false: handle() is finished
        
        TODO: pass this flag from suspend() to resume()
        
     **************************************************************************/

    private bool more = false;
    
    /**************************************************************************

        Exception caught in the fiber to be rethrown in handle()
        
        TODO: pass this exception from suspend() to resume()
        
     **************************************************************************/

    private Exception e_fiber = null;
    
    /**************************************************************************

        Constructor
        
         Params:
             conduit = I/O device
             fiber   = fiber to use to suspend and resume operation
    
     **************************************************************************/

    this ( ISelectable conduit, Fiber fiber, EpollSelectDispatcher epoll )
    {
        super(conduit);
        
        this.warning_e = new IOWarning;
        this.error_e   = new IOError;
        
        this.fiber = fiber;
        this.epoll = epoll;
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
    
    final bool handle ( Event events )
    in
    {
        assert (this.fiber.waiting);
    }
    body
    {
        this.events_reported = events;
        
        this.fiber.resume();
        
        if (this.e_fiber)
        {
            scope (exit) this.e_fiber = null;
            
            throw this.e_fiber;
        }
        
        return this.more;
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
    
    protected void transmitLoop (  )
    in
    {
        assert (this.fiber.running);
    }
    body
    {
        this.epoll.register(this);
        
        try
        {
            this.more = true;
            
            do
            {
                this.fiber.suspend();
            }
            while (this.transmit(this.events_reported))
                
            this.more = false;
            
            this.fiber.suspend();
        }
        catch (KillableFiber.KilledException e)
        {
            throw e;
        }
        catch (Exception e)
        {
            this.e_fiber = e;
            this.fiber.suspend();
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

