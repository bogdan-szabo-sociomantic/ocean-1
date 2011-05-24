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

private import tango.core.Thread : Fiber;

/******************************************************************************/

abstract class IFiberSelectProtocol : ISelectProtocol
{
    /**************************************************************************

        Fiber (may be shared across instances of this class)
    
     **************************************************************************/

    private Fiber fiber;
    
    /**************************************************************************

        Constructor
        
         Params:
             conduit = I/O device
             fiber   = fiber to use to suspend and resume operation
    
     **************************************************************************/

    this ( ISelectable conduit, Fiber fiber )
    {
        super(conduit);
        
        this.warning_e = new IOWarning;
        this.error_e   = new IOError;
        
        this.fiber = fiber;
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
    
     **************************************************************************/

    protected bool handle_ ( )
    in
    {
        assert (this.fiber.state == this.fiber.State.HOLD);
    }
    body
    {
        this.fiber.call();
        
        return this.fiber.state != this.fiber.State.TERM;
    }
    
    /**************************************************************************

        (Re)starts the fiber coroutine.
            
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) start ( )
    {
        if (this.fiber.state == this.fiber.State.TERM)
        {
            this.fiber.reset();
        }
        
        this.fiber.call();
        
        return this;
    }
    
    /**************************************************************************

        Suspends the fiber coroutine. The fiber must be running (EXEC state).
            
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) suspend ( )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.fiber.cede();
        
        return this;
    }
    
    /**************************************************************************

        Returns:
            current fiber state
    
     **************************************************************************/

    public Fiber.State state ( )
    {
        return this.fiber.state;
    }
    
    /**************************************************************************

        Repeatedly invokes again while again returns true; suspends the
        coroutine if again indicates continuation.
        The fiber must be running (EXEC state).
        
        Params:
            again = expression returning true to suspend and be invoked again
                    or false to quit
        
     **************************************************************************/

    protected void repeat ( lazy bool again )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        while (again())
        {
            this.suspend();
        }
    }
    

}

