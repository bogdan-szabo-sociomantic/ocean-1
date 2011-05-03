module ocean.io.select.model.IFiberConnectionHandler;

private import ocean.io.select.model.IConnectionHandler;

private import ocean.io.select.fiberprotocol.model.ISelectProtocol;

private import ocean.io.select.fiberprotocol.SelectReader,
               ocean.io.select.fiberprotocol.SelectWriter;

private import tango.core.Thread : Fiber;

private import tango.net.device.Socket : Socket;

debug private import tango.util.log.Trace;

class IFiberConnectionHandler : IConnectionHandler
{
    Fiber fiber;

    EpollSelectDispatcher dispatcher;

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

        this.fiber = new Fiber(&this.handle);

        this.reader = new SelectReader(socket, this.fiber);
        this.reader.finalizer = this;
        this.reader.error_reporter = this;

        this.writer = new SelectWriter(socket, this.fiber);
        this.writer.finalizer = this;
        this.writer.error_reporter = this;
    }


    protected void register ( ISelectProtocol prot )
    in
    {
        assert(this.fiber.state == this.fiber.State.EXEC);
    }
    body
    {
        this.dispatcher.register(prot);
        this.fiber.cede();
    }

    
    public void assign ( void delegate ( ISelectable ) assign_to_conduit )
    {
        debug Trace.formatln("Assign");

        this.fiber.reset();

        assign_to_conduit(this.reader.conduit);

        this.dispatcher.register(this.reader);
    }

    abstract protected void handle ( );
}

