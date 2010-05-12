/******************************************************************************

    Socket protocol I/O capable of socket error detection and transferring lists
    of arrays or strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt
    
    Description:
    
    Encapsulates socket, protocol reader/writer and buffers for a protocol
    connection via a socket. Checks the socket error status on each
    get/put/commit request to detect a broken connection. A brocken connection
    is automatically disconnected; on next request reconnecting is tried.
    
 ******************************************************************************/

module ocean.io.protocol.SocketProtocol;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.protocol.ListReader;
private import ocean.io.protocol.ListWriter;

private import tango.net.device.Socket;
private import tango.net.device.Berkeley: IPv4Address;

private import tango.io.Buffer;

private import ocean.io.Retry;

private import tango.util.log.Trace;

class SocketProtocol : Socket
{
    /**************************************************************************
    
        Default initial read/write buffer size (bytes)
        
    **************************************************************************/

    static const DefaultBufferSize = 0x800;
    
    /**************************************************************************
    
        This alias for chainable methods
        
    **************************************************************************/

    alias typeof (this) This;
    
    /**************************************************************************
    
        Connection address
        
    **************************************************************************/

    private IPv4Address address;
    
    /**************************************************************************
    
        Protocol reader/writer
        
    **************************************************************************/

    private ListWriter  writer;
    private ListReader  reader;
    
    /**************************************************************************
    
        Connection status
        
    **************************************************************************/

    private bool        connected = false;
    
    /**************************************************************************
    
	    Retry instance for output retrying
	
	 **************************************************************************/
	
	public Retry retry;


    /**************************************************************************
    
        Constructor
        
        Opens a connection to the supplied remote.
        
        Params:
            address   = remote address
            port      = remote port
            buf_size = initial read/write buffer size
        
    **************************************************************************/
    
    this ( char[] address, ushort port, size_t buf_size = DefaultBufferSize )
    {
        this(new IPv4Address(address, port), buf_size, buf_size);
    }

    /**************************************************************************
     
         Constructor
         
         Opens a connection to the supplied remote.
         
         Params:
             address   = remote address
             port      = remote port
             rbuf_size = initial read buffer size
             wbuf_size = initial write buffer size
         
     **************************************************************************/
    
    this ( char[] address, ushort port, size_t rbuf_size, size_t wbuf_size )
    {
        this(new IPv4Address(address, port), rbuf_size, wbuf_size);
    }
    
    /**************************************************************************
    
        Constructor
        
        Opens a connection to the supplied remote.
        
        Params:
            address   = remote address
            buf_size = initial read/write buffer size
        
    **************************************************************************/

    this ( IPv4Address address, size_t buf_size = DefaultBufferSize )
    {
        this(address, buf_size, buf_size);
    }
    
    /**************************************************************************
    
        Constructor
        
        Opens a connection to the supplied remote.
        
        Params:
            address   = remote address
            rbuf_size = initial read buffer size
            wbuf_size = initial write buffer size
        
    **************************************************************************/

    this ( IPv4Address address, size_t rbuf_size, size_t wbuf_size )
    {
        super();

        this.address = address;

        this.connect_();

        this.reader  = new ListReader((new Buffer(rbuf_size)).setConduit(super));
        this.writer  = new ListWriter((new Buffer(wbuf_size)).setConduit(super));

        this.retry = new Retry();

        super.timeout(1000);
    }
    
    /**************************************************************************
    
        Connects to remote, or, if already connected, checks whether the socket
        is OK.
        
        Params:
            clear_buffers = true: If a socket error is detected, clear
                                  read/write buffers after disconnecting.
        
        Returns:
            this instance
        
     **************************************************************************/

    public This connect ( bool clear_buffers = true )
    {
        if (this.connected)
        {
            this.checkSocketOk(clear_buffers);
        }
        else
        {
            this.connect_();
        }
        
        return this;
    }
    
    /**************************************************************************
    
        Disconnects from remote if connected.
        
        Params:
            clear_buffers = true: Clear read/write buffers after disconnecting.
        
        Returns:
            this instance
        
     **************************************************************************/
    
    public This disconnect ( bool clear_buffers = true )
    {
        if (this.connected)
        {
            super.shutdown();
            
            super.native.reopen();
            
            this.connected = false;
            
            if (clear_buffers)
            {
                this.reader.buffer().clear();
                this.writer.buffer().clear();
            }
        }
        
        return this;
    }
    
    
    /**************************************************************************
    
        Receives items in the order of being passed. Supports items of
        elementary type, arrays/strings and lists (arrays) of arrays/strings.
        
        Params:
            items = items to extract (variable argument list)
            
        Returns:
            this instance
    
     **************************************************************************/
    public This get ( T ... ) ( out T items )
    {
//        this.retry.loop(&this.tryGet!(T), &items);

        bool again;
    	this.retry.resetCounter();

    	do try
        {
        	again = false;
        	this.connect();
            this.reader.get(items);
        }
        catch (Exception e)
        {
            again = this.retry(e.msg);
            if ( !again )
            {
           		throw e;
            }
        }
        while (again)

    	return this;
    }

//    void tryGet ( T ... ) ( out T items )
//    {
//Trace.formatln("SocketProtocol.get - try");
//    	this.connect();
//        this.reader.get(items);
//    }

    /**************************************************************************
    
        Sends items in the order of being passed. Supports items of elementary
        type, arrays/strings and lists (arrays) of arrays/strings.
        
        Params:
            items = items to extract (variable argument list)
            
        Returns:
            this instance
    
     **************************************************************************/

    public This put ( T ... ) ( T items )
    {
//    	this.retry.loop(&this.tryPut!(T), items);
        bool again;
    	this.retry.resetCounter();

    	do try
        {
        	again = false;
        	this.connect();
            this.writer.put(items);
        }
        catch (Exception e)
        {
            again = this.retry(e.msg);
            if ( !again )
            {
           		throw e;
            }
        }
        while (again)

        return this;
    }

//    void tryPut ( T ... ) ( T items )
//    {
//Trace.formatln("SocketProtocol.put - try");
//    	this.connect();
//        this.writer.put(items);
//    }

    /**************************************************************************
    
        Clears received input data. 
        
        Returns:
            this instance
    
     **************************************************************************/

    public This clear ()
    {
        this.reader.buffer().clear();
        
        return this;
    }
    
    /**************************************************************************
    
        Commits (flushes) sent output data. 
        
        Returns:
            this instance
    
     **************************************************************************/
    
    /*
     * Note: This method must not be named "flush" because the Conduit abstract
     *       class, from which this class is indirectly derived, also implements
     *       flush() leading to crashes at runtime (segmentation fault or
     *       infinite loop).
     *       Module tango.io.device.Conduit contains the Conduit class.
     */ 
    
    public This commit ( )
    {
        uint i = 0;
        
        bool again;
        this.retry.resetCounter();
        
        this.connect();
        
        do try
        {
            if (again)                                                          // If retrying, reconnect without
            {                                                                   // clearing R/W buffers
                this.disconnect(false).connect(false);
            }
            
            again = false;
            this.writer.flush();
        }
        catch (Exception e)
        {
            again = this.retry(e.msg);
            
            Trace.formatln("commit: {,2} {}", ++i, e.msg);
            
            if (!again)
            {
                throw e;
            }
        }
        while (again)
        
        return this;
    }

    /**************************************************************************
        
        Returns the connection address. 
        
        Returns:
            connection address
    
     **************************************************************************/

    public char[] getAddress ( )
    {
        return this.address.toAddrString();
    }
    
    /**************************************************************************
    
        Returns the connection port. 
        
        Returns:
            connection port
    
     **************************************************************************/

    public ushort getPort ( )
    {
        return this.address.port();
    }

    /**********************************************************************
    
        Checks whether the socket is OK. If not, arranges throwing an
        exception and disconnects the socket.
        
        Params:
            clear_buffers = true: clear buffers when disconnecting on error
        
     **********************************************************************/
    
    private void checkSocketOk ( bool clear_buffers = true )
    {
        scope (failure)
        {
            this.disconnect(clear_buffers);
        }
        
        if (!super.isAlive())
        {
            super.error();
        }
        
        super.checkError();
    }
    
    /**********************************************************************
    
        Connects to remote.
    
     **********************************************************************/

    private void connect_ ( )
    {
        super.connect(this.address);
        
        this.connected = true;
    }
    
    /**********************************************************************
    
        Destructor
    
     **********************************************************************/
    
    private ~this ( )
    {
        if (this.connected)
        {
            super.shutdown().detach();
        }
    }
}
