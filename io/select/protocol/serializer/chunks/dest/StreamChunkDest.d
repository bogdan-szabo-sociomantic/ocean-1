/*******************************************************************************

    Chunk destination which sends array chunks into a stream
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module dht.async.select.protocol.serializer.chunks.dest.StreamChunkDest;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;

private import tango.io.model.IConduit: OutputStream;

private import tango.core.Exception: IOException;
private import ocean.core.Exception: assertEx;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Chunk destination which sends array chunks into a stream

*******************************************************************************/

class StreamChunkDest : IChunkDest!(OutputStream)
{
    /***************************************************************************

        Process a single array, sending it to the output stream. The array's
        length is sent first, then its content.
        
        Params:
            array = array to process
    
    ***************************************************************************/

    public void processArray ( OutputStream output, uint id, void[] array )
    {
        if ( array.length )
        {
            size_t length = array.length;
            this.write(output, (cast(void*)&length)[0 .. length.sizeof]);
            this.write(output, array);
        }
    }


    /***************************************************************************

        Writes data to the output stream.
        
        Params:
            output = output stream
            data  = data to write
    
    ***************************************************************************/

    protected void write ( OutputStream output, void[] data )
    {
        size_t total_sent = 0;
        
        do
        {
            size_t sent = output.write(data[total_sent .. $]);
            
            assertEx!(IOException)(sent != output.Eof, "end of flow whilst writing");
            
            total_sent += sent;
        }
        while ( total_sent < data.length )
    }
}

