module ocean.io.select.model.IChainConnectionHandler;

private import ocean.io.select.model.IConnectionHandler;

private import ocean.io.select.protocol.SelectReader,
               ocean.io.select.protocol.SelectWriter;



class IChainConnectionHandler : IConnectionHandler
{
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
    
    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalize_dg, ErrorDg error_dg )
    {
        super(finalize_dg, error_dg);

        Socket socket = new Socket;
        socket.socket.noDelay(true).blocking(false);

        this.reader = new SelectReader(socket, dispatcher);
        this.reader.finalizer = this;
        this.reader.error_reporter = this;
    
        this.writer = new SelectWriter(socket, dispatcher);
        this.writer.finalizer = this;
        this.writer.error_reporter = this;
    }


    /***************************************************************************

        Initialises the reader and writer. Called whenever a connection is
        assigned, to ensure that the reader & writer states are clean.
    
    ***************************************************************************/
    
    private void init ( )
    {
        this.reader.init();
        this.writer.init();
    }
   
}

