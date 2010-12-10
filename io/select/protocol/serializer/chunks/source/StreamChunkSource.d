/*******************************************************************************

    Chunk source which reads array chunks from a stream

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.source.StreamChunkSource;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.source.model.IChunkSource;

private import tango.io.model.IConduit: InputStream;

private import tango.core.Exception: IOException;
private import ocean.core.Exception: assertEx;

/*******************************************************************************

    Chunk source which reads array chunks from a stream

*******************************************************************************/

class StreamChunkSource : IChunkSource!(InputStream)
{
    /***************************************************************************
    
        Reads the length of the next array from the input stream.
        
        Params:
            input = input stream
        
        Returns:
            length of next array
    
        Throws:
            IOException if input reports EOF
    
    ***************************************************************************/

    public size_t readArrayLength ( hash_t id, InputStream input )
    {
        size_t len;
        
        this.loadInput(input, (cast (void*) &len)[0 .. len.sizeof]);
        
        return len;
    }


    /***************************************************************************
    
        Reads a chunk of content from the input source; chunk.length determines
        the number of bytes to read.
    
        Params:
            input = input stream
            chunk = chunk destination buffer
            
        Throws:
            IOException if input reports EOF
    
    ***************************************************************************/

    public void getNextChunk ( hash_t id, InputStream input, void[] chunk )
    {
        this.loadInput(input, chunk);
    }
    
    
    /***************************************************************************
    
        Tells whether an array is the end of a list.
        
        Params:
            input = input stream (unused; demanded by abstract super class
                    method)
            array = array currently being processed
    
        Returns:
            true if the array being processed is the end of a list
    
    ***************************************************************************/

    public bool endOfList ( InputStream input, void[] array )
    {
        return array.length == 0;
    }
    
    /***************************************************************************
    
        Loads data from input, populating data to its full length.
        
        Params:
            input = input stream
            data  = destination buffer; data.length bytes will be read
    
        Throws:
            IOException if input reports EOF
    
    ***************************************************************************/

    private static void loadInput ( InputStream input, void[] data )
    {
        size_t total = 0;
        
        while (total < data.length)
        {
            size_t received = input.read(data[total .. $]);
            
            assertEx!(IOException)(received != input.Eof, "end of flow whilst reading");
            
            total += received;
        }
    }
}
