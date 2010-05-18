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

private     import      tango.io.Buffer;

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
        
        Buffer
    
     **************************************************************************/
    
    private               IBuffer                         rbuffer, wbuffer;  
    
    private const         size_t                          DefaultBufferSize = 0x1_0000;
    
    /**************************************************************************
    
        Termination flag
    
     **************************************************************************/

    protected static      bool                            terminated = false;
    
    /**************************************************************************
    
        Finished flag for run()
    
     **************************************************************************/

    protected             bool                            finished;
    
    /**************************************************************************
        
        Constructor
    
        Params:
            buffer_size = I/O buffer size
    
     **************************************************************************/
    
    this ( size_t buffer_size )
    {
        this.rbuffer    = new Buffer(buffer_size);
        this.wbuffer    = new Buffer(buffer_size);
        
        this.reader    = new ListReader(rbuffer);
        this.writer    = new ListWriter(wbuffer);
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
            this.rbuffer.clear();                                               // start with a clear conscience
            this.wbuffer.clear();                                               // start with a clear conscience
            
            this.rbuffer.setConduit(conduit);
            this.wbuffer.setConduit(conduit);
            
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
            conduit.detach();
        }
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
