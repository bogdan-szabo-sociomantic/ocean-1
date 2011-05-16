module ocean.io.select.model.IFiberConnectionHandler;

private import ocean.io.select.fiberprotocol.SelectReader,
               ocean.io.select.fiberprotocol.SelectWriter;

private import ocean.io.select.model.IConnectionHandler;

private import ocean.io.select.model.ISelectClient;

private import tango.core.Thread : Fiber;

private import tango.net.device.Socket : Socket;

debug private import tango.util.log.Trace;

class IFiberConnectionHandler : IConnectionHandler
{
    protected Fiber fiber;

    protected EpollSelectDispatcher dispatcher;

    /***************************************************************************

        Local aliases for SelectReader and SelectWriter.
    
    ***************************************************************************/
    
    public alias .SelectReader SelectReader;
    public alias .SelectWriter SelectWriter;
    
    
    /***************************************************************************
    
        SelectReader and SelectWriter used for asynchronous protocol i/o.
    
    ***************************************************************************/
    
    protected SelectReader reader;
    protected SelectWriter writer;

    invariant
    {
        assert (this.reader.conduit is this.writer.conduit);
    }

    /***************************************************************************

        Constructor.
    
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
        this.reader.finalizer = this;
        this.reader.error_reporter = this;

        this.writer = new SelectWriter(socket, this.fiber);
        this.writer.finalizer = this;
        this.writer.error_reporter = this;
    }
    
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

        this.fiber.reset();

        this.fiber.call();
    }
    
    /***************************************************************************
    
        Handler coroutine method. Waits for data to read from the socket and
        invokes handle(), repeating that procedure while handle() returns true.
    
    ***************************************************************************/

    private void handleLoop ( )
    {
        scope (exit) super.finalize();
        
        uint n = 0;
        
        do
        {
            this.register(this.reader);
        }
        while (this.handle(n++))
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
    
        Registers client in the select dispatcher.
        Note: The coroutine must be running. 
        
        Params:
            client = select client to register
        
    ***************************************************************************/

    protected void register ( ISelectClient client )
    in
    {
        assert(this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.dispatcher.register(client);
        this.fiber.cede();
    }
    
    /***************************************************************************
    
        Closes the client connection socket. 
        
    ***************************************************************************/

    protected void closeSocket ( )
    {
        (cast (Socket) this.writer.conduit).shutdown().close();
    }
}

