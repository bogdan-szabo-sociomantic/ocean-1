/*******************************************************************************

    Base class for a connection handler for use with SelectListener, using
    Fibers.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        David Eckardt, Gavin Norman

*******************************************************************************/

module ocean.io.select.model.IFiberConnectionHandler;

/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.fiber.model.IFiberSelectProtocol,
               ocean.io.select.protocol.fiber.FiberSelectReader,
               ocean.io.select.protocol.fiber.FiberSelectWriter;

private import ocean.io.select.model.IConnectionHandler;

private import tango.core.Thread : Fiber;

private import tango.net.device.Socket : Socket;

private import tango.io.Stdout;

/******************************************************************************/

class IFiberConnectionHandler : IConnectionHandler
{
   /***************************************************************************

        Local aliases for SelectReader and SelectWriter.
    
    ***************************************************************************/
    
    public alias .FiberSelectReader SelectReader;
    public alias .FiberSelectWriter SelectWriter;
    
    /***************************************************************************
    
        SelectReader and SelectWriter used for asynchronous protocol i/o.
    
    ***************************************************************************/
    
    protected SelectReader reader;
    protected SelectWriter writer;
    
    private Fiber fiber;
    
    /***************************************************************************
    
        EpollSelectDispatcher instance
    
    ***************************************************************************/

    private EpollSelectDispatcher dispatcher;

    /**************************************************************************/
    
    invariant
    {
        assert (this.reader.conduit is this.writer.conduit);
    }

    /***************************************************************************

        Constructor
    
        Connects the socket, the asynchronous reader and writer, and the
        provided epoll select dispatcher.
    
        Params:
            dispatcher = epoll select dispatcher which this connection should
                use for i/o
            finalize_dg = user-specified finalizer, called when the connection
                is shut down
            error_dg = user-specified error handler, called when a connection
                error occurs
    
    ***************************************************************************/
    
    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalize_dg = null, ErrorDg error_dg = null )
    {
        super(finalize_dg, error_dg);

        Socket socket = new Socket;
        socket.socket.noDelay(true).blocking(false);

        this.dispatcher = dispatcher;

        this.fiber = new Fiber(&this.handleLoop);
        
        this.reader = new SelectReader(socket, this.fiber);
        this.writer = new SelectWriter(socket, this.fiber);

        this.reader.error_reporter = super;
        this.writer.error_reporter = super;
        
        static uint N = 0;
        
        this.n = ++N;
    }
    
    protected uint n;
    
    /***************************************************************************
        
        Invokes assign_to_conduit with the connection socket of this instance
        and starts the handler coroutine.
    
        Params:
            assign_to_conduit = delegate passed from SelectListener which
                accepts the incoming connection with the conduit passed to it
    
    ***************************************************************************/

    public void assign ( void delegate ( ISelectable ) assign_to_conduit )
    {
        assign_to_conduit(this.reader.conduit);
        
        this.start();
    }
    
    /***************************************************************************
    
        Handler coroutine method. Waits for data to read from the socket and
        invokes handle(), repeating that procedure while handle() returns true.
    
    ***************************************************************************/

    private void handleLoop ( )
    {
        uint n = 0;
        
        bool more = false;
        
        do
        {
            this.register(this.reader);
            
            more = this.handle(n++);
            
            if (more)
            {
                this.reader.finalizer = null;                                   // If more, prevent this instance from being
                this.writer.finalizer = null;                                   // finalized when reader and/or writer are finished. 
            }
        }
        while (more)
    }
    
    /***************************************************************************
    
        Connection handle method. When it gets called, the socket is ready for
        reading.
        
        Params:
            n = counter for the number of times handle() has been invoked since
                instantiation or after it returned false the last time 
        
        Returns:
            true to be invoked again after the socket has become ready for
            reading or false to exit the handleLoop() and finalize this instance
        
    ***************************************************************************/

    abstract protected bool handle ( uint n );
    
    /***************************************************************************
    
        Closes the client connection socket. 
        
    ***************************************************************************/

    protected void closeSocket ( )
    {
        Socket socket = cast (Socket) this.writer.conduit;
        assert (socket !is null);
        socket.shutdown().close();
    }
    
    version (all)
    {
        /***************************************************************************
        
            Registers client in the select dispatcher.
            Sets this instance as client finalizer because super.finalize(), which
            returns this instance to the object pool, must be invoked in the case
            when the select dispatcher gets a socket error event.
            Since the handler() methods of this.reader/this.writer, which resume the
            coroutine and would normally set the finalizer later on, are the
            handlers invoked from the select dispatcher, the coroutine will not be
            resumed in case of a socket error event ant therefore have no chance to
            properly set the finalizer, resulting in this instance never being
            returned to the object pool.
            
            TODO: discuss this subtle issue with Gavin
            
            Note: The coroutine must be running. 
            
            Params:
                client = select client to register
            
        ***************************************************************************/
        
        protected void register ( IFiberSelectProtocol client )
        in
        {
            assert (this.fiber.state == this.fiber.state.EXEC);
        }
        body
        {
            client.finalizer = super;
            this.dispatcher.register(client);
            
            this.suspend();
        }
    
        /**************************************************************************
    
            (Re)starts the fiber coroutine.
                
            Returns:
                this instance
        
         **************************************************************************/
        
        protected void start ( )
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
            
            this.resume();
        }
        
        /**************************************************************************
    
            (Re)starts the fiber coroutine.
                
            Returns:
                this instance
        
         **************************************************************************/
        
        protected void resume ( )
        in
        {
            assert (this.fiber.state == this.fiber.State.HOLD);
        }
        body
        {
            this.fiber.call();
        }
        
        /**************************************************************************
        
            Suspends the fiber coroutine. The fiber must be running (EXEC state).
                
            Returns:
                this instance
        
         **************************************************************************/
        
        protected void suspend ( )
        in
        {
            assert (this.fiber.state == this.fiber.State.EXEC);
        }
        body
        {
            this.fiber.cede();
        }
    }
    else
    {
        protected void register ( IFiberSelectProtocol client )
        {
            this.fiber.register(client);
        }
        
        private class ConnectionFiber : IFiberSelectProtocol.ConnectionFiber
        {
            private IFiberSelectProtocol client = null;
            
            private Fiber fiber;
            
            this ( )
            {
                this.fiber = new Fiber(&this.outer.handleLoop);
            }
            
            /***************************************************************************
            
                Registers client in the select dispatcher.
                Sets this instance as client finalizer because super.finalize(), which
                returns this instance to the object pool, must be invoked in the case
                when the select dispatcher gets a socket error event.
                Since the handler() methods of this.reader/this.writer, which resume the
                coroutine and would normally set the finalizer later on, are the
                handlers invoked from the select dispatcher, the coroutine will not be
                resumed in case of a socket error event ant therefore have no chance to
                properly set the finalizer, resulting in this instance never being
                returned to the object pool.
                
                TODO: discuss this subtle issue with Gavin
                
                Note: The coroutine must be running. 
                
                Params:
                    client = select client to register
                
            ***************************************************************************/
        
            public void register ( IFiberSelectProtocol client )
            in
            {
                assert (this.running);
            }
            body
            {
                this.client = client;
                client.finalizer = this.outer;
                
                this.suspend();
            }
            
            /**********************************************************************
    
                (Re)starts the fiber coroutine. The fiber must not be running (EXEC
                state).
            
             **********************************************************************/
            
            public void start ( )
            in
            {
                assert (!this.running);
            }
            body
            {
                if (this.finished)
                {
                    this.fiber.reset();
                }
                
                this.fiber.call();
            }
            
            /**********************************************************************
        
                Resumes the fiber coroutine. The fiber must be suspended (HOLD
                state).
            
             **********************************************************************/
            
            public void resume ( )
            in
            {
                assert (this.client !is null);
                assert (this.waiting);
            }
            body
            {
                this.outer.dispatcher.unregister(this.client);
                this.fiber.call();
            }
            
            /**********************************************************************
            
                Suspends the fiber coroutine. The fiber must be running (EXEC
                state).
            
             **********************************************************************/
            
            public void suspend ( )
            in
            {
                assert (this.client !is null);
                assert (this.running);
            }
            body
            {
                this.outer.dispatcher.register(this.client);
                this.fiber.cede();
            }
            
            public bool waiting ( )
            {
                return this.fiber.state == this.fiber.state.HOLD;
            }
            
            public bool running ( )
            {
                return this.fiber.state == this.fiber.state.EXEC;
            }
            
            public bool finished ( )
            {
                return this.fiber.state == this.fiber.state.TERM;
            }
        }
    }
}

