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

private import ocean.io.select.fiber.SelectFiber;

private import ocean.io.select.EpollSelectDispatcher;

private import tango.core.Exception: IOException;

debug private import ocean.util.log.Trace;

/******************************************************************************

    IFiberSelectClient abstract class

 ******************************************************************************/

abstract class IFiberSelectClient : IAdvancedSelectClient
{
    /**************************************************************************

        Type alias for subclass constructors
    
     **************************************************************************/

    public alias .SelectFiber SelectFiber;
    
    /**************************************************************************

        Fiber instance
    
     **************************************************************************/

    public const SelectFiber fiber;

    /**************************************************************************

        Flag set to true when the error_() method is called due to an I/O error
        event. The flag is always reset in the finalize() method.

     **************************************************************************/

    public bool io_error;

    /**************************************************************************
    
        Constructor
    
        Params:
            conduit = I/O device instance
            fiber   = fiber to resume on finalize() or kill on error()
    
     **************************************************************************/
    
    protected this ( ISelectable conduit, SelectFiber fiber )
    {
        super(conduit);
        this.fiber = fiber;
    }
    
    /**************************************************************************
    
        Finalize method, called after this instance has been unregistered from
        the Dispatcher; resumes the fiber and calls the super-class' finalize()
        method (which calls a finalizer delegate, if one has been set).
        
        The fiber must be waiting or finished as it is ought to be when in
        Dispatcher context.
        
     **************************************************************************/
    
    public override void finalize ( )
    {
        assert (!this.fiber.running);
        
        try
        {
            if (this.fiber.waiting)
            {
                this.fiber.kill();
            }
    
            this.fiber.clear();
            super.finalize();
        }
        finally
        {
            this.io_error = false;
        }
    }

    /**************************************************************************
    
        Error reporting method, called when an Exception is caught from
        handle(); kills the fiber.
        
        Params:
            exception = Exception thrown by handle()
            event     = Selector event while exception was caught
        
     **************************************************************************/

    protected override void error_ ( Exception e, Event event )
    {
        this.io_error = cast(IOException)e !is null;
        
        if (this.fiber.waiting)
        {
            this.fiber.kill(__FILE__, __LINE__);
        }

        super.error_(e, event);
    }


    /**************************************************************************

        Timeout method, called after this a timeout has occurred in the
        SelectDispatcher; kills the fiber.

     **************************************************************************/

    override public void timeout ( )
    {
        if (this.fiber.waiting)
        {
            this.fiber.kill(__FILE__, __LINE__);
        }

        super.timeout();
    }
}

