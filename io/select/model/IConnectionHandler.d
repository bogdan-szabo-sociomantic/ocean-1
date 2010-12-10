module ocean.io.select.model.IConnectionHandler;

import ocean.io.select.SelectDispatcher;
import ocean.io.select.protocol.SelectReader,
       ocean.io.select.protocol.SelectWriter;

import ocean.io.select.model.ISelectClient : IAdvancedSelectClient;

import tango.net.device.Socket;


abstract class IConnectionHandler
{
    alias void delegate ( typeof (this) ) FinalizeDg;
    
    private class Finalizer : IAdvancedSelectClient.IFinalizer
    {
        private FinalizeDg finalize_dg;
        
        this ( FinalizeDg finalize_dg )
        {
            this.finalize_dg = finalize_dg;
        }
        
        void finalize ( )
        {
            this.finalize_dg(this.outer);
        }
    }
    
    protected SelectReader reader;
    protected SelectWriter writer;
    
    this ( SelectDispatcher dispatcher, FinalizeDg finalize_dg )
    {
        Socket socket = new Socket;
        
        socket.socket.blocking = false;
        
        Finalizer finalizer = new Finalizer(finalize_dg);
        
        this.reader = new SelectReader(socket, dispatcher);
        this.writer = new SelectWriter(socket, dispatcher);
        
        this.reader.finalizer = finalizer;
        this.writer.finalizer = finalizer;
    }
    
    abstract typeof (this) assign ( void delegate ( ISelectable ) );
}

