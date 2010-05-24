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

private import tango.io.Buffer;

private import ocean.io.Retry;

debug private import tango.util.log.Trace;

/*******************************************************************************

	SocketRetry class, derived from Retry.
	Only handles socket-based exceptions: SocketException & IOException.

*******************************************************************************/

class SocketRetry : Retry
{
	private import tango.core.Exception;

    /***************************************************************************
    
		Constructor.
	
	    Params:
	        delg = retry callback delegate

	***************************************************************************/

	public this ( CallbackDelg delg )
    {
    	super(delg);
    }


    /***************************************************************************
    
		Overloaded try / catch / retry loop which only catches exceptions of
		type SocketException or IOException.
	
	    Params:
	        code_block = code to try
	
	***************************************************************************/

    deprecated public override void loop ( void delegate () code_block )
    {
    	bool again;
    	super.resetCounter();

    	do try
        {
    		again = false;
        	code_block();
        }
        catch ( SocketException e )
        {
        	debug Trace.formatln("caught {} {}", typeof(e).stringof, e.msg);
        	super.handleException(e, again);
        }
        catch ( IOException e )
        {
        	debug Trace.formatln("caught {} {}", typeof(e).stringof, e.msg);
        	super.handleException(e, again);
        }
        while (again)
    }
}



/*******************************************************************************

	SocketProtocol class, derived from socket

*******************************************************************************/

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

    protected ListWriter writer;
    protected ListReader reader;
    
    /**************************************************************************
    
        Connection status
        
    **************************************************************************/

    private bool connected = false;
	
    /**************************************************************************
	    
		Retry object
	
	 **************************************************************************/

    public SocketRetry retry;

	
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

        super.timeout(1000);

//        this.retry = new SocketRetry(&this.retryReconnect);
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
            this.connected = false;
            
            super.shutdown();
            super.native.reopen();
            
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
        this.reader.buffer().clear();
        
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

// FIXME: no yet tested! may fail!
    
version (None) 
{
    /**************************************************************************
    
	    Commits (flushes) sent output data. 
	    
	    Retries the commit operation in accordance with the retry member's
	    settings.

	    Returns:
	        this instance
	
	 **************************************************************************/
	
    /// FIXME: causes Segmentation Fault
    
	deprecated public This commitRetry ( )
	{
		this.retry.loop({
			this.commit();
		});
	    return this;
	}
    
    /**************************************************************************
        
        Receives items in the order of being passed. Supports items of
        elementary type, arrays/strings and lists (arrays) of arrays/strings.
    
        Retries the get operation in accordance with the retry member's settings.
    
        Params:
            items = items to extract (variable argument list)
            
        Returns:
            this instance
    
     **************************************************************************/
    
    deprecated public This getRetry ( T ... ) ( out T items )
    {
        this.retry.loop({
            this.get(items);
        });
        return this;
    }
    
    
    /**************************************************************************
    
        Sends items in the order of being passed. Supports items of elementary
        type, arrays/strings and lists (arrays) of arrays/strings.
        
        Retries the put operation in accordance with the retry member's settings.
        
        TODO 
        
        Params:
            items = items to extract (variable argument list)
            
        Returns:
            this instance
    
     **************************************************************************/
    
    deprecated public This putRetry ( T ... ) ( T items )
    {
        this.retry.loop({
            this.put(items);
        });
        return this;
    }


    /***************************************************************************
    
		Reconnect method, used as the loop callback for the retry member to wait
		for a time then try disconnecting and reconnecting the socket.

		Params:
			msg = message describing the action being retried

    	Returns:
        	true to try again

    ***************************************************************************/

    deprecated public bool retryReconnect ( char[] msg )
	{
		debug Trace.formatln("SocketProtocol, reconnecting");
		bool again = this.retry.wait(msg);
		if ( again )                                                          	// If retrying, reconnect without
	    {                                                                   	// clearing R/W buffers
			try
			{
				this.disconnect(false).connect(false);
			}
			catch ( Exception e )
			{
				debug Trace.formatln("Socket reconnection failed: {}", e.msg);
			}
	    }
		debug Trace.formatln("Try again? {}", again ? "yes" : "no");
		return again;
	}
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
