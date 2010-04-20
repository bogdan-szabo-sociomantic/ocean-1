/*******************************************************************************

    Connection handler for ServerSocketThread
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        March 2010: Initial release
    
    authors:        David Eckardt
    
    Invoked by ServerSocketThread on incoming connection; manages a persistent
    client connection. Stops when client breaks the connection or hangs-up on
    it.
    A class for a connection handler created and invoked by ServerSocketThread
    must implement dispatch(). For socket I/O the reader/writer class properties
    are available to a subclass.
    
 ******************************************************************************/

module ocean.net.socket.model.IConnectionHandler;

/******************************************************************************

    Imports
    
 ******************************************************************************/

private import ocean.io.protocol.ListReader;
private import ocean.io.protocol.ListWriter;

private import ocean.util.TraceLog;

private import tango.io.Buffer;

private import tango.io.model.IBuffer;
private import tango.io.model.IConduit;

private import tango.core.Runtime;

private import tango.core.Exception: IOException;

private import tango.util.log.Trace;

/******************************************************************************

    ConnectionHandlery class
    
 ******************************************************************************/

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
    
    private               IBuffer                         buffer;  
    
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
        this.buffer    = new Buffer(buffer_size);
        
        this.reader    = new ListReader(buffer);
        this.writer    = new ListWriter(buffer);
    } 
    
    /**************************************************************************
    
        Constructor
    
     **************************************************************************/

    this ( )
    {
        this(this.DefaultBufferSize);
    }
    
    /**************************************************************************
        
        Handle connection
        
        Params:
            conduit = connection conduit (e.g. socket)
    
     **************************************************************************/
    
    public void run ( IConduit conduit )
    {
        if (this.terminated) return;
        
        this.buffer.setConduit(conduit);
        
        try 
        {
            this.finished = false;
            
            while (!this.terminated && !this.finished)
            {
                // start with a clear conscience
                this.buffer.clear();
                
                // wait for something to arrive before we try/catch
                this.buffer.slice(1, false);
                  
                if (this.terminated) return;
                
                this.dispatch();
                // send response back to client
                
                this.buffer.flush();
            }
        } 
        catch (IOException e)
        {
            if (!Runtime.isHalting())
            {
                TraceLog.write("socket exception '{}'", e);
                Trace.formatln("socket exception '{}'", e);
            }
        }
        catch (Exception e)
        {
            TraceLog.write("runtime exception '{}'", e);
            Trace.formatln("runtime exception '{}'", e);
        }
        finally
        {
            conduit.detach();
            
            this.buffer.clear();
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
        
        delete this.buffer;
    }
}
