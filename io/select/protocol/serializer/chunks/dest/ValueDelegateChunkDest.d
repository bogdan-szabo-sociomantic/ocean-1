/*******************************************************************************

    Chunk destination which sends array chunks into a delegate
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.dest.ValueDelegateChunkDest;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.ChunkDelegates;

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;

private import ocean.io.select.protocol.serializer.chunks.dest.model.ChunkDestType;



/*******************************************************************************

    Chunk destination which sends array chunks into a delegate

*******************************************************************************/

class ValueDelegateChunkDest : IChunkDest!(ChunkDelegates.GetValueDg)
{
    /***************************************************************************

        Process a single array, sending it to the output delegate.
        
        Params:
            output = output delegate
            array  = array to process
    
    ***************************************************************************/

    public void processArray ( ChunkDelegates.GetValueDg output, void[] array )
    {
        output(cast(char[])array);
    }
}

