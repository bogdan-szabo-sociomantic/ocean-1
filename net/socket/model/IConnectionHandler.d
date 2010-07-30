/*******************************************************************************

    Connection handler for ServerSocketThread
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        March 2010: Initial release
    
    authors:        David Eckardt
    
    Abstract class for a connection handler invoked by ServerSocketThread. A 
    subclass must implement dispatch(). For conduit (socket) I/O the
    reader/writer class properties are available to the subclass.
    
*******************************************************************************/

module ocean.net.socket.model.IConnectionHandler;

/******************************************************************************

    Imports
    
*******************************************************************************/

private     import      ocean.io.protocol.ListReader, 
                        ocean.io.protocol.ListWriter;

private     import      tango.io.stream.Buffered;

private     import      tango.io.model.IBuffer, tango.io.model.IConduit;

private     import      tango.core.Runtime;

private     import      tango.core.Exception: IOException;

debug 
{
    private import ocean.util.TraceLog;
    private import tango.util.log.Trace;
}

/******************************************************************************

    ConnectionHandlery
    
*******************************************************************************/

abstract class IConnectionHandler
{
    /**************************************************************************
    
        Hash type alias
        
     **************************************************************************/

    alias               typeof (this)                   This;
    
    /**************************************************************************
        
        Protocol reader & writer
    
     **************************************************************************/
    
    protected             ListWriter                      writer;
    protected             ListReader                      reader;
    
    /**************************************************************************
        
        Buffers
    
     **************************************************************************/
    
    protected BufferedInput rbuffer;
    protected BufferedOutput wbuffer;
    
    private const         size_t                          DefaultBufferSize = 0x10_000;
    
    /**************************************************************************
    
        Conduit to client
    
     **************************************************************************/

    protected IConduit conduit;

    /**************************************************************************
    
        Termination flag
    
     **************************************************************************/

    protected static      bool                            terminated = false;
    
    /**************************************************************************
    
        Finished flag for run()
    
     **************************************************************************/

    protected             bool                            finished;
    
    /**************************************************************************
        
        Constructor. The ListReader/Writer are initialised without a buffer.
		The buffer is attached in the run method, when we have a conduit to
		properly attach everything to.

        Params:
            buffer_size = I/O buffer size
    
     **************************************************************************/
    
    this ( size_t buffer_size )
    {
        this.rbuffer    = new BufferedInput(null, buffer_size);
        this.wbuffer    = new BufferedOutput(null, buffer_size);

        this.reader    = new ListReader();
        this.writer    = new ListWriter();
    }

    /**************************************************************************
    
        Constructor; uses default I/O buffer size
    
     **************************************************************************/

    this ( )
    {
        this(this.DefaultBufferSize);
    }
    
    /**************************************************************************
        
        Handles a client connection. Stops when the "finished" (for temporary
        connections) or the "terminate" flag (for persistent connections) is set
        to true or the client closes/breaks the connection.
        
        Params:
            conduit = connection conduit (e.g. socket)
    
     **************************************************************************/
    
    public void run ( IConduit conduit )
    {
        if (this.terminated) return;
        
        this.finished = false;

        try 
        {
        	this.attachConduit(conduit);
            
            this.rbuffer.slice(1, false);                                       // wait for something to arrive before we try/catch
              
            while (!this.terminated && !this.finished)
            {
            	this.dispatch();
                
                this.wbuffer.flush();                                           // send response back to client
            }
        } 
        catch (IOException e)
        {
            if (!Runtime.isHalting())
            {
                debug
                {
                    TraceLog.write("socket exception '{}'", e.msg);
                    Trace.formatln("socket exception '{}'", e.msg);
                }
            }
        }
        catch (Exception e)
        {
            debug
            {
                TraceLog.write("runtime exception '{}'", e.msg);
                Trace.formatln("runtime exception '{}'", e.msg);
            }
        }
        finally
        {
        	this.detachConduit(conduit);
        }
    }

    /***************************************************************************

    	Connect the reader & writer, the in/out buffers and the passed conduit.
		(Previous data in the buffers is flushed first by the called Reader /
		Writer methods).

	    Params:
	        conduit = connection conduit (e.g. socket)

    ***************************************************************************/
    
    protected void attachConduit ( IConduit conduit )
    {
    	this.reader.connectBufferedInput(this.rbuffer, conduit);
    	this.writer.connectBufferedOutput(this.wbuffer, conduit);
    	this.conduit = conduit;
    }

    /***************************************************************************

		Detach a conduit from the read & write buffers. Any data remaining in
		the buffers is flushed by the called methods before disconnection.

	    Params:
	        conduit = connection conduit (e.g. socket)

	***************************************************************************/

    protected void detachConduit ( IConduit conduit )
    {
    	this.reader.disconnectBufferedInput();
    	this.writer.disconnectBufferedOutput();
        conduit.detach();
        this.conduit = null;
    }

    /**************************************************************************
    
        Sets the termination flag for all instances of this class
            
     **************************************************************************/

    static void terminate ( )
    {
        this.terminated = true;
    }
    
    /**************************************************************************
    
        Dispatch connection
        
        This method is invoked when data have arrived.
        
     **************************************************************************/
    
    abstract protected void dispatch ( ) ;

    /**************************************************************************
    
        Destructor
        
     **************************************************************************/
    
    private ~this ( )
    {
        delete this.reader;
        delete this.writer;
        
        delete this.rbuffer;
        delete this.wbuffer;
    }
}
