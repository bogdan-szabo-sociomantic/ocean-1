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

private import tango.io.Buffer: GrowBuffer;

private import tango.io.model.IBuffer;
private import tango.io.model.IConduit;

private import tango.core.Runtime;

private import tango.core.Exception: IOException, IllegalArgumentException;

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
    
    private const         size_t                          BUFFER_SIZE_INIT = 0x2000;
    
    /**************************************************************************
        
        Set socket conduit & DHT nodes
        
        Params:
            dht_node_items = list (array) of DHT nodes to connect to
    
     **************************************************************************/
    
    this ( )
    {
        this.buffer    = new GrowBuffer(this.BUFFER_SIZE_INIT);
        
        this.reader    = new ListReader(buffer);
        this.writer    = new ListWriter(buffer);
    } 
    
    /**************************************************************************
        
        Handle connection
        
        Params:
            conduit = connection conduit (e.g. socket)
    
     **************************************************************************/
    
    public void run ( IConduit conduit )
    {
        this.buffer.setConduit(conduit);
        
        try 
        {
            while (true)
            {
                  // start with a clear conscience
                  this.buffer.clear();
                  
                  // wait for something to arrive before we try/catch
                  this.buffer.slice(1, false);
                  
                  try 
                  {
                      this.dispatch();
                  } 
                  catch (Exception e)
                  {
                      TraceLog.write("request error '{}'", e);
                  }
                  // send response back to client
                  
                  this.buffer.flush();
            }
        } 
        catch (IOException e)
        {
            if (!Runtime.isHalting())
            {
                TraceLog.write("socket exception '{}'", e);
            }
        }
        catch (Exception e)
        {
            TraceLog.write("runtime exception '{}'", e);
        }
        
        conduit.detach();
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
