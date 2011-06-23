/******************************************************************************

    Base class for fiber based registrable client objects for the
    SelectDispatcher

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        June 2011: Initial release
    
    authors:        David Eckardt
    
    Contains the five things that the fiber based SelectDispatcher needs:
        1. the I/O device instance,
        2. the I/O events to register the device for,
        3. the event handler to invocate when an event occured for the device,
        4. the finalizer that resumes the fiber,
        5. the error handler that kills the fiber.
        
 ******************************************************************************/

module ocean.io.select.model.IFiberSelectClient;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.model.ISelectClient;

private import ocean.io.select.protocol.fiber.model.MessageFiber: MessageFiber;

/******************************************************************************

    IFiberSelectClient abstract class

 ******************************************************************************/

abstract class IFiberSelectClient : IAdvancedSelectClientWithoutFinalizer
{
    /**************************************************************************

        Fiber instance
    
     **************************************************************************/

    protected MessageFiber fiber;
    
    /**************************************************************************
    
        Constructor
    
        Params:
            conduit = I/O device instance
            fiber   = fiber to resume on finalize() or kill on error()
    
     **************************************************************************/
    
    protected this ( ISelectable conduit, MessageFiber fiber )
    {
        super(conduit);
        this.fiber = fiber;
    }
    
    /**************************************************************************
    
        Finalize method, called after this instance has been unregistered from
        the Dispatcher; resumes the fiber.
        
        In:
            The fiber must waiting or finished as it is ought to be when in
            Dispatcher context.
        
     **************************************************************************/
    
    public override void finalize ( )
    in
    {
        assert (!this.fiber.running);
    }
    body
    {
        if (this.fiber.waiting)
        {
            this.fiber.resume();
        }
    }
    
    /**************************************************************************
    
        Error reporting method, called when an Exception is caught from
        handle(); kills the fiber.
        
        Params:
            exception: Exception thrown by handle()
            event:     Selector event while exception was caught
        
     **************************************************************************/
    
    public override void error ( Exception e, Event event )
    {
        scope (exit) if (this.fiber.waiting)
        {
            this.fiber.kill();
        }
        
        super.error(e, event);
    }
}
