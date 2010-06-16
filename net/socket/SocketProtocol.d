/******************************************************************************

    Socket protocol I/O capable of socket error detection and transferring lists
    of arrays or strings

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt
    
    Description:
    
    Encapsulates socket, protocol reader/writer and buffers for a protocol
    connection via a socket. Checks the socket error status on each
    get/put/commit request to detect a broken connection. A broken connection
    is automatically disconnected; on next request reconnecting is tried.

    The socket protocol class also encapsulates a Retry object, which can
    (optionally) be used by external classes to repeatedly retry socket
    operations, with a disconnection and reconnection after each failed attempt.

    Note that using the retry member is left up to the user of the
    SocketProtocol. It cannot be wrapped internally around every socket
    operation, as only the end user can determine which operations are safe to
    retry indefinitely.
    
    Example usage:

	---

		scope socket = new SocketProtocol("192.168.2.25", 4712);
		
		// Write something to the socket.
		socket.put("hello");
		
		// Get soemthing from the socket.
		char[] read;
		socket.get(read);

		// Retry a group of operations with the socket.
		socket.retry.loop({
			socket.put("hello");
			socket.get(read);
		});

	---
		
 ******************************************************************************/

module ocean.io.protocol.SocketProtocol;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.protocol.ListReader;
private import ocean.io.protocol.ListWriter;

private import tango.net.device.Socket;
private import tango.net.device.Berkeley: IPv4Address;

private import tango.io.stream.Buffered;

debug 
{
	private import tango.util.log.Trace;
}

/*******************************************************************************

	SocketProtocol class, derived from socket

*******************************************************************************/

class SocketProtocol : Socket
{
    /**************************************************************************
    
        Default initial read/write buffer size (bytes)
        
    **************************************************************************/

    static const DefaultBufferSize = 64 * 1024;
    
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

    protected BufferedInput bin;
    protected BufferedOutput bout;

    /**************************************************************************
    
	    Buffered input / output
	    
	**************************************************************************/

    protected ListWriter writer;
    protected ListReader reader;
    
    /**************************************************************************
    
        Connection status
        
    **************************************************************************/

    private bool connected = false;

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

        this.bin = new BufferedInput(super, this.DefaultBufferSize);
        this.bout = new BufferedOutput(super, this.DefaultBufferSize);
        this.reader  = new ListReader(this.bin);
        this.writer  = new ListWriter(this.bout);
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
            clear_buffers = true: Clear read/write buffers before disconnecting.
        
        Returns:
            this instance
        
     **************************************************************************/
    
    public This disconnect ( bool clear_buffers = true )
    {
        if (this.connected)
        {
            if (clear_buffers)
            {
                this.bin.clear();
                this.bout.clear();
            }

            this.connected = false;
            
            super.shutdown();
            super.native.reopen();
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
        scope (failure) 
        {
            this.disconnect(true);
        }
        
       	this.connect();
        this.reader.get(items);
    	return this;
    }


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
        scope (failure) 
        {
            this.disconnect(true);
        }
        
    	this.connect();
        this.writer.put(items);
        return this;
    }	

    /**************************************************************************
    
        Clears received input data. 
        
        Returns:
            this instance
    
     **************************************************************************/

    public This clear ()
    {
        this.bin.clear();
        
        return this;
    }
    
    /**************************************************************************
    
        Commits (flushes) sent output data. 
        
        Note: This method must not be named "flush" because the Conduit 
        abstract class, from which this class is indirectly derived, also 
        implements flush() leading to crashes at runtime (segmentation fault 
        or infinite loop).  Module tango.io.device.Conduit contains the Conduit 
        class.
        
        Returns:
            this instance
    
     **************************************************************************/
    
    public This commit ()
    {
        scope (failure) 
        {
            this.disconnect(true);
        }
        
    	this.connect();
        this.writer.flush();
        
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
        scope ( failure )
            this.connected = false;

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
