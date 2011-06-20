/****************************************************************************** 

    Wraps a Fiber allowing to pass a message on suspending/resuming and to kill
    the fiber.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Jun 2011: Initial release

    authors:        David Eckardt
    
    Allows passing a message from suspend() to resume() and vice versa.
    Provides a kill() method where kill() resumes suspend() and suspend() throws
    a KilledException when it was resumed by kill(). 
    
 ******************************************************************************/

module ocean.io.select.protocol.fiber.model.MessageFiber;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.core.Thread : Fiber;

private import ocean.core.Array: copy;

private import ocean.core.SmartUnion;

/******************************************************************************/

class MessageFiber
{
    union Message_
    {
        int    num;
        void*  ptr;
        Object obj;
    }
    
    alias SmartUnion!(Message_) Message;
    
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

        Message passed between suspend() and resume()
    
     **************************************************************************/

    private Message         msg;
    
    /**************************************************************************

        Exception instance set by suspendThrow() and thrown by resume()
    
     **************************************************************************/
    
    private Exception       e = null;

    /**************************************************************************

        KilledException instance
    
     **************************************************************************/
    
    private KilledException e_killed;

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
    
        Starts or resumes the fiber coroutine and waits until it is suspended
        or finishes.
        
        Params:
            msg = message to be returned by the next suspend() call.
        
        Returns:
            When the fiber is suspended, the message passed to the that
            suspend() call.
        
        Throws:
            Exception if the fiber is suspended by suspendThrow().
        
        In:
            The fiber must not be running (but waiting or finished).
        
     **************************************************************************/
    
    public Message start ( Message msg = Message.init )
    in
    {
        assert (this.fiber.state != this.fiber.State.EXEC);
    }
    body
    {
        if (this.fiber.state == this.fiber.State.TERM)
        {
            this.fiber.reset();
            this.msg = this.msg.init;
        }
        
//        this.fiber.call();
        return this.resume(msg);
    }
    
    /**************************************************************************
    
        Suspends the fiber coroutine and waits until it is resumed or killed.
        
        Params:
            msg = message to be returned by the next start()/resume() call.
        
        Returns:
            When the fiber is resumed, the message passed to that start() or
            resume() call. 
        
        Throws:
            KilledException if the fiber is killed.
        
        In:
            The fiber must be running (not waiting or finished).
        
     **************************************************************************/

    public Message suspend ( Message msg = Message.init )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        scope (exit)
        {
            this.msg = msg;
            this.suspend_();
        }
        
        return this.msg;
    }
    
    /**************************************************************************
    
        Suspends the fiber coroutine, makes the next start() or resume() call
        throw e (instead of resuming) and waits until the fiber is resumed by
        the second next resume() call or killed.
        
        Returns:
            e when the fiber is resumed by the second-next call to start() or
            resume().
        
        Throws:
            KilledException if resumed by kill().
        
        In:
            The fiber must be running (not waiting or finished).
        
     **************************************************************************/
    
    public Exception suspendThrow ( Exception e )
    in
    {
        assert (e !is null);
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.e = e;
        this.suspend_();
        return e;
    }

    /**************************************************************************
    
        Resumes the fiber coroutine and waits until it is suspended or killed.
        
        However, if the fiber was just suspended by suspendThrow(), this call
        will throw the exception instance passed to suspendThrow() instead of
        resuming the fiber and the next call will resume it.
            
        Params:
            msg = message to be returned by the next suspend() call.
        
        Returns:
            When the fiber is suspended, the message passed to that suspend()
            call.
        
        Throws:
            Exception if the fiber was just suspended by suspendThrow().
        
        In:
            The fiber must be waiting (not running or finished).
        
     **************************************************************************/
    
    public Message resume ( Message msg = Message.init )
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
            scope (exit) this.msg = msg;
            this.fiber.call();
            return this.msg;
        }
    }

    /**************************************************************************
    
        Kills the fiber coroutine. That is, resumes it and makes resume() throw
        a KilledException.
        
        Param:
            file = source file (passed to the exception)
            line = source code line (passed to the exception)
        
        Returns:
            When the fiber is suspended by suspend() or finishes.
            
        In:
            The fiber must be waiting (not running or finished).
    
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
    
    /**************************************************************************
    
        Suspends the fiber.
        
        Throws:
            suspendThrow() exception if pending
    
        In:
            The fiber must be running (not waiting or finished).

     **************************************************************************/

    private void suspend_ ( )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.fiber.cede();
        
        if (this.killed)
        {
            this.killed = false;
            throw this.e_killed;
        }
    }
}
