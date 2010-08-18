/*******************************************************************************

    Connection handler for ServerSocketThread
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        March 2010: Initial release
    
    authors:        David Eckardt
    
********************************************************************************/

module ocean.net.socket.model.IConnectionHandler;

/*******************************************************************************

	Imports
    
********************************************************************************/

private	import	ocean.io.protocol.ListReader, 
                ocean.io.protocol.ListWriter;

private import  tango.io.stream.Buffered;

private import  tango.io.model.IBuffer, tango.io.model.IConduit;

private import  tango.core.Runtime;

private import  tango.core.Exception: IOException;

debug 
{
    private import tango.util.log.Trace;
}

/*******************************************************************************

    Connection Handler
    
    Abstract class for a connection handler invoked by ServerSocketThread. A 
    subclass must implement dispatch(). For conduit (socket) I/O the
    reader/writer class properties are available to the subclass.
       
********************************************************************************/

abstract class IConnectionHandler
{
    
    /***************************************************************************
    
        Hash type alias
        
     **************************************************************************/

    alias               typeof (this)		This;
    
    /***************************************************************************
        
        Protocol reader & writer
    
     **************************************************************************/
    
    protected           ListWriter          writer;
    protected           ListReader          reader;
    
    /***************************************************************************
        
        Buffers
    
     **************************************************************************/
    
    protected           BufferedInput       rbuffer;
    protected           BufferedOutput      wbuffer;
    
    /***************************************************************************
        
        Default buffer size
    
     **************************************************************************/
    
    private const       size_t              DefaultBufferSize = 0x10_000;
    
    /***************************************************************************
    
        Conduit to client
    
     **************************************************************************/

    protected           IConduit            conduit;

    /***************************************************************************
    
        Termination flag
    
     **************************************************************************/

    protected           static bool         terminated = false;
    
    /***************************************************************************
    
        Finished flag for run()
    
     **************************************************************************/

    protected           bool                finished;
    
    /***************************************************************************
        
        Constructor. The ListReader/Writer are initialised without a buffer.
		The buffer is attached in the run method, when we have a conduit to
		properly attach everything to.

        Params:
            buffer_size = I/O buffer size
    
     **************************************************************************/
    
    public this ( size_t buffer_size )
    {
        this.rbuffer    = new BufferedInput(null, buffer_size);
        this.wbuffer    = new BufferedOutput(null, buffer_size);

        this.reader    = new ListReader();
        this.writer    = new ListWriter();
    }

    /***************************************************************************
    
        Constructor; uses default I/O buffer size
    
     **************************************************************************/

    public this ( )
    {
        this(this.DefaultBufferSize);
    }
    
    /***************************************************************************
        
        Destructor
        
     **************************************************************************/
    
    public ~this ( )
    {
        delete this.reader;
        delete this.writer;
        
        delete this.rbuffer;
        delete this.wbuffer;
    }

    /***************************************************************************
        
        Handles a client connection. Stops when the "finished" (for temporary
        connections) or the "terminate" flag (for persistent connections) is set
        to true or the client closes/breaks the connection.
        
        Params:
            conduit = connection conduit (e.g. socket)
    
     **************************************************************************/
    
    public void run ( IConduit conduit )
    {
        bool error;
        
        if (this.terminated) return;
        
        this.finished = false;

        try
        {
        	this.attachConduit(conduit);

            this.rbuffer.slice(1, false);                                       // wait for something to arrive

            while (!this.terminated && !this.finished)
            {
            	this.dispatch();
                
                this.wbuffer.flush();                                           // send response back to client
            }
        }
        catch (IOException e)
        {
            error = true;
            debug if (!Runtime.isHalting())
            {
        		Trace.formatln("IConnectionHandler socket exception '{}'", e.msg);
            }
        }
        catch (Exception e)
        {
            error = true;
            debug
            {
                Trace.formatln("IConnectionHandler runtime exception '{}'", e.msg);
            }
        }
        finally
        {
        	this.detachConduit(conduit, !error);
        }
    }

    /***************************************************************************

    	Connect the reader & writer, the in/out buffers and the passed conduit.
		(Previous data in the buffers is flushed first by the called Reader /
		Writer methods).

	    Params:
	        conduit = connection conduit (e.g. socket)

     **************************************************************************/
    
    protected void attachConduit ( IConduit conduit )
    {
        this.conduit = conduit;
        
        this.reader.connectBufferedInput(this.rbuffer, this.conduit);
        this.writer.connectBufferedOutput(this.wbuffer, this.conduit);
    }

    /***************************************************************************

		Detach a conduit from the read & write buffers. Any data remaining in
		the buffers is optionally flushed by the called methods before
        disconnection.
        
        After the conduit is detached, the read & write buffers are cleared.

	    Params:
	        conduit = connection conduit (e.g. socket)
            flush_buffers = whether to flush the read & write buffers before
                detaching the conduit

	 **************************************************************************/

    protected void detachConduit ( IConduit conduit, bool flush_buffers )
    {
        this.reader.disconnectBufferedInput(flush_buffers);
        this.writer.disconnectBufferedOutput(flush_buffers);
        
        conduit.detach();

        this.rbuffer.clear();
        this.wbuffer.clear();
        
        this.conduit = null;
   	}

    /***************************************************************************
    
        Sets the termination flag for all instances of this class
            
     **************************************************************************/

    static void terminate ()
    {
        this.terminated = true;
    }
    
    /***************************************************************************
    
        Dispatch connection
        
        This method is invoked when data has arrived. Needs to be implemented
        by derived classes.
        
     **************************************************************************/
    
    abstract protected void dispatch ( );
}

