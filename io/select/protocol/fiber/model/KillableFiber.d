/****************************************************************************** 

    Wraps a Fiber instance providing a means to kill it when it is waiting.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Jun 2011: Initial release

    authors:        David Eckardt
    
    Provides a suspend() and a kill() method where kill() resumes suspend() and
    suspend() throws a KilledException when it was resumed by kill(). 
    
 ******************************************************************************/

module ocean.io.select.protocol.fiber.model.KillableFiber;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.core.Thread : Fiber;

private import ocean.core.Array: copy;

private import tango.io.Stdout;

/******************************************************************************/

class KillableFiber
{
    /**************************************************************************

        KilledException; thrown by suspend() when resumed by kill()
    
     **************************************************************************/

    static class KilledException : Exception
    {
        this ( )  {super("Fiber killed");}
        
        void set ( char[] file, long line )
        {
            super.file.copy(file);
            super.line = line;
        }
    }
    
    /**************************************************************************

        Fiber instance
    
     **************************************************************************/

    private Fiber fiber;
    
    /**************************************************************************

        KilledException instance
    
     **************************************************************************/

    private KilledException e_killed;
    
    private Exception       e = null;
    
    /**************************************************************************

        "killed" flag, set by kill() and cleared by resume().
    
     **************************************************************************/

    private bool killed = false;
    
    /**************************************************************************

        Constructor
        
        Params:
            coroutine = fiber coroutine
    
     **************************************************************************/

    this ( void delegate ( ) coroutine )
    {
        this.fiber = new Fiber(coroutine);
        this.e_killed     = new KilledException;
    }
    
    /**************************************************************************

        Constructor
        
        Params:
            routine = fiber coroutine
            sz      = fiber stack size
    
     **************************************************************************/

    this ( void delegate ( ) coroutine, size_t sz )
    {
        this.fiber = new Fiber(coroutine, sz);
        this.e_killed     = new KilledException;
    }
    
    /**************************************************************************
    
        Starts or resumes the fiber coroutine.
        
        Returns:
            When the fiber is suspended by suspend().
        
        In:
            The fiber must not be running (but be either finished or waiting).
        
     **************************************************************************/
    
    public void start ( )
    in
    {
        assert (this.fiber.state != this.fiber.State.EXEC);
    }
    body
    {
        if (this.fiber.state == this.fiber.State.TERM)
        {
            this.fiber.reset();
        }
        
        this.fiber.call();
    }
    
    /**************************************************************************
    
        Suspends the fiber coroutine.
        
        Returns:
            When the fiber is resumed by resume().
        
        Throws:
            KilledException if resumed by kill().
        
        In:
            The fiber must be running.
        
     **************************************************************************/
    
    public Exception suspend ( Exception e = null )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.e = e;
        
        this.fiber.cede();
        
        if (this.killed)
        {
            this.killed = false;
            throw this.e_killed;
        }
        else
        {
            return e;
        }
    }

    /**************************************************************************
        
        Resumes the fiber coroutine.
            
        Returns:
            When the fiber is suspended by suspend() or finishes.
        
        In:
            The fiber must be waiting.
        
     **************************************************************************/

    public void resume ( )
    in
    {
        assert (this.fiber.state == this.fiber.State.HOLD);
    }
    body
    {
        if (this.e)
        {
            scope (exit) this.e = null;
            throw this.e;
        }
        else
        {
            this.fiber.call();
        }
    }
    
    /**************************************************************************
    
        Kills the fiber coroutine. That is, resumes it and makes resume() throw
        a KilledException.
        
        Returns:
            When the fiber is suspended by suspend() or finishes.
            
        Returns:
            this instance
    
     **************************************************************************/
    
    public void kill ( char[] file = null, long line = 0 )
    in
    {
        assert (this.fiber.state == this.fiber.State.HOLD);
        assert (!this.killed);
    }
    body
    {
        this.killed = true;
        this.e_killed.set(file, line);
        
        this.fiber.call(false);
    }

    /**************************************************************************
    
        Returns:
            true if the fiber is waiting or false otherwise.
    
     **************************************************************************/

    public bool waiting ( )
    {
        return this.fiber.state == this.fiber.State.HOLD;
    }
    
    /**************************************************************************
    
        Returns:
            true if the fiber is running or false otherwise.
    
     **************************************************************************/

    public bool running ( )
    {
        return this.fiber.state == this.fiber.State.EXEC;
    }
    
    /**************************************************************************
    
        Returns:
            true if the fiber is finished or false otherwise.
    
     **************************************************************************/

    public bool finished ( )
    {
        return this.fiber.state == this.fiber.State.TERM;
    }
}
