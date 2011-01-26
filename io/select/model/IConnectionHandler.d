/******************************************************************************

    Base class for a connection handler SelectListener

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    authors:        David Eckardt

 ******************************************************************************/

module ocean.io.select.model.IConnectionHandler;

version (NewSelectProtocol) import ocean.io.select.protocol.SelectProtocol;
else                        import ocean.io.select.protocol.SelectReader,
                                   ocean.io.select.protocol.SelectWriter;

private import ocean.io.select.model.ISelectListenerInfo;

private import ocean.io.select.EpollSelectDispatcher;
    
private import ocean.io.select.model.ISelectClient : IAdvancedSelectClient;

private import tango.net.device.Socket: Socket;

private import tango.io.model.IConduit: ISelectable;

debug private import tango.util.log.Trace;



abstract class IConnectionHandler : IAdvancedSelectClient.IFinalizer
{
    alias .ISelectable    ISelectable;
    
    alias .EpollSelectDispatcher EpollSelectDispatcher;
    
    
    
    alias void delegate ( typeof (this) ) FinalizeDg;

    private FinalizeDg finalize_dg;

    protected void finalize ( )
    {
        if ( this.finalize_dg )
        {
            this.finalize_dg(this);
        }
    }

    
    
    version (NewSelectProtocol)
    {
        alias .SelectProtocol SelectProtocol;
        
        protected SelectProtocol protocol;
    }
    else
    {
        alias .SelectReader SelectReader;
        alias .SelectWriter SelectWriter;
        
        protected SelectReader reader;
        protected SelectWriter writer;
    }
    
    public this ( EpollSelectDispatcher dispatcher, FinalizeDg finalize_dg )
    {
        Socket socket = new Socket;
        
        socket.socket.blocking = false;

        this.finalize_dg = finalize_dg;

        version (NewSelectProtocol)
        {
            this.protocol = new SelectProtocol(socket, dispatcher);
            this.protocol.finalizer = this;
        }
        else
        {
            this.reader = new SelectReader(socket, dispatcher);
            this.writer = new SelectWriter(socket, dispatcher);
            
            this.reader.finalizer = this;
            this.writer.finalizer = this;
        }
    }

	// Always reset this instance when a new connection is assigned.
	// In the case where the previous connection this instance handled ended
	// normally, this initialisation is not strictly necessary.
	// However in the case where the previous connection was terminated prematurely,
	// the initialisation is needed.
    public typeof (this) assign ( ISelectListenerInfo listener_info, void delegate ( ISelectable ) assign_to_conduit )
    {
    	this.init();

        this.assign_(listener_info, assign_to_conduit);
        return this;
    }

    abstract protected void assign_ ( ISelectListenerInfo, void delegate ( ISelectable ) );

	private void init ( )
	{
        this.reader.init();
        this.writer.init();
	}
}

