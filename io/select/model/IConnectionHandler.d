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

import ocean.io.select.EpollSelectDispatcher;
    
import ocean.io.select.model.ISelectClient : IAdvancedSelectClient;

import tango.net.device.Socket: Socket;

import tango.io.model.IConduit: ISelectable;

abstract class IConnectionHandler
{
    alias .ISelectable    ISelectable;
    
    alias void delegate ( typeof (this) ) FinalizeDg;
    
    alias .EpollSelectDispatcher EpollSelectDispatcher;
    
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
    
    this ( EpollSelectDispatcher dispatcher, FinalizeDg finalize_dg )
    {
        Socket socket = new Socket;
        
        socket.socket.blocking = false;
        
        version (NewSelectProtocol)
        {
            this.protocol = new SelectProtocol(socket, dispatcher);
            this.protocol.finalizer = new Finalizer(finalize_dg);
        }
        else
        {
            Finalizer finalizer = new Finalizer(finalize_dg);
            
            this.reader = new SelectReader(socket, dispatcher);
            this.writer = new SelectWriter(socket, dispatcher);
            
            this.reader.finalizer = finalizer;
            this.writer.finalizer = finalizer;
        }
    }
    
    abstract typeof (this) assign ( void delegate ( ISelectable ) );
}

