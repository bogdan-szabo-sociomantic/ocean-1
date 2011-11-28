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

module ocean.core.MessageFiber;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.core.Thread : Fiber;

private import ocean.core.Array: copy;

private import ocean.core.SmartUnion;

/******************************************************************************/

interface MessageFiberControl
{
    alias MessageFiber.Message         Message;
    alias MessageFiber.KilledException KilledException;
    
    MessageFiber.Message suspend ( Message msg = Message.init );
    MessageFiber.Message resume  ( Message msg = Message.init );
    
    bool running  ( );
    bool waiting  ( );
    bool finished ( );
}

/******************************************************************************/

class MessageFiber : MessageFiberControl
{
    /**************************************************************************

        Message union
    
     **************************************************************************/

    private union Message_
    {
        int       num;
        void*     ptr;
        Object    obj;
        Exception exc;
    }
    
    public alias SmartUnion!(Message_) Message;
    
    /**************************************************************************

        Alias for fiber state
    
     **************************************************************************/

    public alias Fiber.State State;

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

    private const Fiber           fiber;
    
    /**************************************************************************

        Message passed between suspend() and resume()
    
     **************************************************************************/

    private Message         msg;
    
    /**************************************************************************

        KilledException instance
    
     **************************************************************************/
    
    private const KilledException e_killed;

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
        this.e_killed = new KilledException;
        this.msg.num = 0;
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
        this.e_killed = new KilledException;
        this.msg.num = 0;
    }
    
    /**************************************************************************
    
        Starts or resumes the fiber coroutine and waits until it is suspended
        or finishes.
        
        Params:
            msg = message to be returned by the next suspend() call.
        
        Returns:
            When the fiber is suspended, the message passed to that suspend()
            call. It has always an active member, by default num but never exc.
        
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
    out (msg_out)
    {
        auto a = msg_out.active;
        assert (a);
        assert (a != a.exc);
    }
    body
    {
        if (this.fiber.state == this.fiber.State.TERM)
        {
            this.fiber.reset();
            this.msg.num = 0;
        }
        
        return this.resume(msg);
    }
    
    /**************************************************************************
    
        Suspends the fiber coroutine and waits until it is resumed or killed. If
        the active member of msg is msg.exc, exc will be thrown by the resuming
        start()/resume() call.
        
        Params:
            msg = message to be returned by the next start()/resume() call.
        
        Returns:
            the message passed to the resume() call which made this call resume.
            It has always an active member, by default num but never exc.
            
        Throws:
            KilledException if the fiber is killed.
        
        In:
            The fiber must be running (not waiting or finished).
            If the active member of msg is msg.exc, it must not be null.
        
     **************************************************************************/

    public Message suspend ( Message msg = Message.init )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC);
        with (msg) if (active == active.exc) assert (exc !is null);
    }
    out (msg_out)
    {
        auto a = msg_out.active;
        assert (a);
        assert (a != a.exc);
    }
    body
    {
        if (!msg.active)
        {
            msg.num = 0;
        }

        scope (exit)
        {
            this.msg = msg;
            this.suspend_();
        }
        
        return this.msg;
    }
    
    /**************************************************************************
    
        Suspends the fiber coroutine, makes the resuming start()/resume() call
        throw e and waits until the fiber is resumed or killed.
        
        Params:
            e = Exception instance to be thrown by the next start()/resume()
            call.
        
        Returns:
            the message passed to the resume() call which made this call resume.
            It has always an active member, by default num but never exc.
        
        Throws:
            KilledException if the fiber is killed.
        
        In:
            e must not be null and the fiber must be running (not waiting or
            finished).
        
     **************************************************************************/

    public Message suspend ( Exception e )
    in
    {
        assert (e !is null);
    }
    body
    {
        return this.suspend(Message(e));
    }
    
    /**************************************************************************
    
        Resumes the fiber coroutine and waits until it is suspended or killed.
            
        Params:
            msg = message to be returned by the next suspend() call. It has
            always an active member, by default num but never exc.
        
        Returns:
            The message passed to the suspend() call which made this call
            resume.
        
        Throws:
            if an Exception instance was passed to the suspend() call which made
            this call be resumed, that Exception instance.  
        
        In:
            The fiber must be waiting (not running or finished).
        
     **************************************************************************/
    
    public Message resume ( Message msg = Message.init )
    in
    {
        assert (this.fiber.state == this.fiber.State.HOLD);
    }
    out (msg_out)
    {
        auto a = msg_out.active;
        assert (a);
        assert (a != a.exc);
    }
    body
    {
        if (!msg.active)
        {
            msg.num = 0;
        }
        
        scope (exit) this.msg = msg;
        this.fiber.call();
        
        if (this.msg.active == this.msg.active.exc)
        {
            throw this.msg.exc;
        }
        else
        {
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

        Returns:
            fiber state
    
     **************************************************************************/

    public State state ( )
    {
        return this.fiber.state;
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
