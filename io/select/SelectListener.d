module ocean.io.select.SelectListener;

import ocean.io.select.SelectDispatcher;
import ocean.io.select.model.ISelectClient;

import ocean.core.ObjectPool;

import tango.net.device.Socket;
import tango.net.device.Berkeley: IPv4Address;

import ocean.io.select.model.IConnectionHandler;

import tango.io.Stdout;

class SelectListener ( T : IConnectionHandler ) : ISelectClient
{
    private IPv4Address address;
    
    private ObjectPool!(T, SelectDispatcher, IConnectionHandler.FinalizeDg) receiver_pool;
    
    private SelectDispatcher dispatcher;
    
    this ( char[] address, ushort port, SelectDispatcher dispatcher,
           int backlog = 32, bool reuse = true )
    {
        this(new IPv4Address(address, port), dispatcher, backlog, reuse);
    }

    this ( IPv4Address address, SelectDispatcher dispatcher,
           int backlog = 32, bool reuse = false )
    {
        this.address    = address;
        this.dispatcher = dispatcher;
        
        auto socket = new ServerSocket(this.address, backlog, reuse);
        
        socket.socket.blocking = false;
        
        super(socket);
        
        this.receiver_pool = this.receiver_pool.newPool(dispatcher, &this.returnToPool);
        
        dispatcher.register(this);
    }
    
    private void returnToPool ( IConnectionHandler connection )
    {
        this.receiver_pool.recycle(cast (T) connection);
    }
    
    Event events ( )
    {
        return Event.Read;
    }
    
    private uint i = 0;
    
    bool handle ( ISelectable server_socket, Event event )
    in
    {
        assert (conduit is super.conduit);
    }
    body
    {
        this.i++;
        
        Stderr.formatln("\n{}: accepting", i);
        
        this.receiver_pool.get().assign((ISelectable conduit)
        {
             (cast (ServerSocket) server_socket).accept(cast (Socket) conduit);
        });
        
        Stderr.formatln("{}: accepted", i);
        
        return true;
    }
}

