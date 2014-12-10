/******************************************************************************

    Wraps a Fiber allowing to pass a message on suspending/resuming and to kill
    the fiber.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        Jun 2011: Initial release

    authors:        David Eckardt

    Allows passing a message from suspend() to resume() and vice versa.
    Provides a kill() method where kill() resumes suspend() and suspend() throws
    a KilledException when it was resumed by kill().

    suspend() and resume() require you to pass a 'token' parameter to them
    which must be the same for each suspend/resume pair. This prevents that
    a fiber is resumed from a part of the code that wasn't intended to do so.

    Still, sometimes the correct position in a code could resume a fiber
    that was waiting for a resume from another instance of the same code
    (for example, a fiber is being resumed from a wrong class instance).
    To catch these cases, a runtime-identifier parameter was added,
    which is just an Object reference. If another object is resuming a fiber
    an exception is thrown.

    See also the documentation of suspend/resume.

    Note: You can use -debug=MessageFiber to print the identifiers that
          were used in the suspend/resume calls. It uses the FirstNames
          functions to print pointers as names.

          You can use -debug=MessageFiberDump to enable a function called
          'dumpFibers' which can be called from within gdb using
          'call dumpFibers()'. The performance impact should be relatively low.
          It will output a list on STDERR listing all fibers and some
          informations about their state.

          Example output:

      Tomsen: State: TERM; Token: GroupRequest; LastSuspend: 1364929361 (157s ago); Addr: 7ff6c9ec8f00; Suspender: core.input.TrackingLoglineSource.FiberGroupRetry!(GetRange).FiberGroupRetry
      Marine: State: TERM; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9eef100; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
      Robert: State: TERM; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9f94a00; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
      Batman: State: HOLD; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9f94300; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
       David: State: TERM; Token:  event_fired; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9fc7c00; Suspender: ocean.io.select.client.FiberSelectEvent.FiberSelectEvent
       Gavin: State: HOLD; Token:     io_ready; LastSuspend: 1364929357 (161s ago); Addr: 7ff6c9fc7500; Suspender: swarm.core.protocol.FiberSelectReader.FiberSelectReader
    Superman: State: HOLD; Token:  DrizzleData; LastSuspend: 1364929515 (3s ago); Addr: 7ff6cad40800; Suspender: ocean.db.drizzle.Connection.Connection
       Gavin: State: HOLD; Token:  DrizzleData; LastSuspend: 1364929515 (3s ago); Addr: 7ff6cad40600; Suspender: ocean.db.drizzle.Connection.Connection

 ******************************************************************************/

module ocean.core.MessageFiber;

/******************************************************************************

    Imports

 ******************************************************************************/

import tango.core.Thread : Fiber;

import ocean.core.Array: copy;

import ocean.core.SmartUnion;

import ocean.io.digest.Fnv1;

debug ( MessageFiber )
{
    import tango.io.Stdout;
    debug = MessageFiberToken;
}

debug ( MessageFiberDump )
{
    import tango.time.Clock;
    import tango.core.Array;
    import tango.core.Memory;
    import tango.io.Stdout;
    debug = MessageFiberToken;
}

debug ( MessageFiberToken )
{
    import ocean.io.digest.FirstName;
}


/******************************************************************************

    Dump information about fibers to STDERR

 ******************************************************************************/

debug ( MessageFiberDump ) extern(C) void dumpFibers()
{
    char[][] state_str = [ "HOLD" ,"EXEC" ,"TERM" ];

    void* wpFiber = MessageFiber.last_fiber;

    while ( wpFiber !is null )
    {
        auto fiber = cast(MessageFiber) GC.weakPointerGet(wpFiber);

        wpFiber = null;

        if ( fiber !is null )
        {
            Stderr.formatln("{,12}: State: {}; Token: {,12}; LastSuspend: {} ({}s ago); "
                "Addr: {}; Suspender: {}",
                FirstName(fiber), state_str[fiber.fiber.state],
                fiber.last.str, fiber.time,
                fiber.time > 0 ? Clock.now().unix().seconds() - fiber.time : 0,
                cast(void*) fiber,
                fiber.suspender);

            wpFiber= fiber.prev_fiber;
        }
    }
}

/******************************************************************************/

class MessageFiber
{
    debug ( MessageFiberDump )
    {
        /**********************************************************************

            Most recent token

        **********************************************************************/

        private Token last;

        /**********************************************************************

            Last time suspend was called

        **********************************************************************/

        private size_t time;

        /**********************************************************************

            Name of the suspender, taken from the identifier parameter
            Empty string if identifier wasn't given.

        **********************************************************************/

        private char[] suspender;

        /**********************************************************************

            List of weakpointers to all fibers

        **********************************************************************/

        static private void* last_fiber;

        private void* next_fiber, prev_fiber;
    }

    /**************************************************************************

        Token struct passed to suspend() and resume() methods in order to ensure
        that the fiber is resumed for the same reason as it was suspended. The
        token is constructed from a string, via the static opCall() method.

        Usage example:

        ---

            auto token = MessageFiber.Token("something_happened");

            fiber.suspend(token);

            // Later on, somewhere else
            fiber.resume(token);

        ---

     **************************************************************************/

    public struct Token
    {
        /***********************************************************************

            String used to construct the token. In debug builds this is used for
            nice message output.

        ***********************************************************************/

        private debug (MessageFiberToken) char[] str;

        /***********************************************************************

            Hash of string used to construct the token.

        ***********************************************************************/

        private hash_t hash;

        /***********************************************************************

            Constructs a token.

            Params:
                s = string

            Returns:
                token constructed from the passed string

        ***********************************************************************/

        public static Token opCall ( char[] s )
        {
            Token token;
            token.hash = Fnv1a64(s);
            debug (MessageFiberToken) token.str = s;
            return token;
        }
    }

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
            super.file = file;
            super.line = line;
        }
    }

    /**************************************************************************

        ResumedException; thrown by suspend() when resumed with the wrong
        identifier

     **************************************************************************/

    static class ResumeException : Exception
    {
        this ( )  {super("Resumed with invalid identifier!");}

        ResumeException set ( char[] file, long line )
        {
            super.file = file;
            super.line = line;

            return this;
        }
    }

    /**************************************************************************

        Fiber instance

     **************************************************************************/

    private Fiber     fiber;

    /**************************************************************************

        Identifier

     **************************************************************************/

    private ulong           identifier;

    /**************************************************************************

        Message passed between suspend() and resume()

     **************************************************************************/

    private Message         msg;

    /**************************************************************************

        KilledException instance

     **************************************************************************/

    private KilledException e_killed;

    /**************************************************************************

        ResumeException instance

     **************************************************************************/

    private ResumeException e_resume;

    /**************************************************************************

        "killed" flag, set by kill() and cleared by resume().

     **************************************************************************/

    private bool killed = false;

    /**************************************************************************

        Constructor

        Params:
            coroutine = fiber coroutine

     **************************************************************************/

    public this ( void delegate ( ) coroutine )
    {
        this.fiber = new Fiber(coroutine);
        this.e_killed = new KilledException;
        this.e_resume = new ResumeException;
        this.msg.num = 0;

        debug(MessageFiberDump) addToList();
    }

    /**************************************************************************

        Constructor

        Params:
            routine = fiber coroutine
            sz      = fiber stack size

     **************************************************************************/

    public this ( void delegate ( ) coroutine, size_t sz )
    {
        this.fiber = new Fiber(coroutine, sz);
        this.e_killed = new KilledException;
        this.e_resume = new ResumeException;
        this.msg.num = 0;

        debug(MessageFiberDump) addToList();
    }

    /**************************************************************************

        Destructor

        Removes the Fiber from the linked list and destroys its weak pointer

     **************************************************************************/

    debug(MessageFiberDump) ~this ( )
    {
        auto next = cast(MessageFiber) GC.weakPointerGet(next_fiber);
        auto prev = cast(MessageFiber) GC.weakPointerGet(prev_fiber);
        void* me;

        if ( next !is null )
        {
            if ( MessageFiber.last_fiber == next.prev_fiber )
            {
                MessageFiber.last_fiber = next_fiber;
            }

            me = next.prev_fiber;
            next.prev_fiber = prev_fiber;
        }

        if ( prev !is null )
        {
            me = prev.next_fiber;
            prev.next_fiber = next_fiber;
        }

        GC.weakPointerDestroy(me);
    }

    /**************************************************************************

        Adds this fiber to the linked list of Fibers

     **************************************************************************/

    debug(MessageFiberDump) void addToList ( )
    {
        auto me = GC.weakPointerCreate(this);

        if ( last_fiber !is null )
        {
            auto l = cast(MessageFiber) GC.weakPointerGet(MessageFiber.last_fiber);

            assert ( l !is null );

            l.next_fiber = me;
            prev_fiber = last_fiber;
        }

        last_fiber = me;
    }

    /**************************************************************************

        Starts the fiber coroutine and waits until it is suspended or finishes.

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
        assert (this.fiber.state != this.fiber.State.EXEC, "attempt to start an active fiber");
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

        Token token;
        return this.resume(token, null, msg);
    }

    /**************************************************************************

        Suspends the fiber coroutine and waits until it is resumed or killed. If
        the active member of msg is msg.exc, exc will be thrown by the resuming
        start()/resume() call.

        Params:
            token = token expected to be passed to resume()
            identifier = reference to the object causing the suspend, use null
                         to not pass anything. The caller to resume must
                         pass the same object reference or else a ResumeException
                         will be thrown inside the fiber
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

    public Message suspend ( Token token, Object identifier = null, Message msg = Message.init )
    in
    {
        assert (this.fiber.state == this.fiber.State.EXEC, "attempt to suspend an inactive fiber");
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

            debug (MessageFiber) Stdout.formatln("--FIBER {} SUSPENDED -- ({}:{})",
                FirstName(this), token.str, FirstName(identifier));

            debug ( MessageFiberDump )
            {
                this.last = token;
                this.time = Clock.now().unix().seconds();
                this.suspender = identifier !is null ? identifier.classinfo.name : "";
            }

            this.suspend_();

            if ( this.identifier != this.createIdentifier(token.hash, identifier) )
            {
                throw this.e_resume.set(__FILE__, __LINE__);
            }
        }

        return this.msg;
    }

    /**************************************************************************

        Suspends the fiber coroutine, makes the resuming start()/resume() call
        throw e and waits until the fiber is resumed or killed.

        Params:
            token = token expected to be passed to resume()
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

    public Message suspend ( Token token, Exception e )
    in
    {
        assert (e !is null);
    }
    body
    {
        return this.suspend(token, null, Message(e));
    }

    /**************************************************************************

        Resumes the fiber coroutine and waits until it is suspended or killed.

        Params:
            token = token expected to have been passed to suspend()
            identifier = reference to the object causing the resume, use null
                         to not pass anything. Must be the same reference
                         that was used in the suspend call, or else a
                         ResumeException will be thrown inside the fiber.
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

    public Message resume ( Token token, Object identifier = null, Message msg = Message.init )
    in
    {
        assert (this.fiber.state == this.fiber.State.HOLD, "attempt to resume a non-held fiber");
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

        this.identifier = this.createIdentifier(token.hash, identifier);

        debug (MessageFiber) Stdout.formatln("--FIBER {} RESUMED -- ({}:{})",
                FirstName(this), token.str, FirstName(identifier));

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
        assert (this.fiber.state == this.fiber.State.HOLD, "attempt to kill a non-helpd fiber");
        assert (!this.killed);
    }
    body
    {
        debug (MessageFiber) Stdout.formatln("--FIBER {} KILLED -- ({}:{})",
                FirstName(this), file, line);

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

        Resets the fiber

     **************************************************************************/

    public void reset ( )
    {
        this.fiber.reset();
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
        assert (this.fiber.state == this.fiber.State.EXEC, "attempt to suspend a non-active fiber");
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

    /**************************************************************************

        Generates an identifier from a hash and an object reference.

        Params:
            hash = hash to generate identifier from
            obj = object reference to generate identifier from

        Returns:
            identifier based on provided hash and object reference (the two are
            XORed together)

     **************************************************************************/

    static private ulong createIdentifier ( hash_t hash, Object obj )
    {
        return hash ^ cast(ulong)cast(void*)obj;
    }
}

