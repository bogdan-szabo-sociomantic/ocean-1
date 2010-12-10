/*******************************************************************************

    Chunk destination which puts array chunks into a buffer
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.dest.BufferChunkDest;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;

debug private import tango.util.log.Trace;


/*******************************************************************************

    Chunk destination which puts array chunks into a buffer
    
    T is the data array base type and must be a single-byte type.
    
*******************************************************************************/

template BufferChunkDest ( T )
{
    static assert (T.sizeof == char.sizeof, "BufferChunkDest: single byte data "
                  "array base type required, not '" ~ T.stringof ~ '\'');
    
    class BufferChunkDest : IChunkDest!(T[]*)
    {
        /**********************************************************************
    
            Process a single array, appending it to the output buffer.
            
            Params:
                output = output destination buffer 
                array  = array to process
        
        ***********************************************************************/
    
        public void processArray ( T[]* output, uint id, void[] array )
        {
            *output ~= cast (char[]) array;
        }
    }
}