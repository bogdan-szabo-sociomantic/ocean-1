/*******************************************************************************

    Chunk destination which puts pairs of array chunks into a delegate
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.dest.PairDelegateChunkDest;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;

private import ocean.io.request.params.RequestParams;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Chunk destination which puts pairs of array chunks into a delegate

*******************************************************************************/

class PairDelegateChunkDest : IChunkDest!(RequestParams.GetPairDg)
{
    /***************************************************************************

        Buffers arrays until a pair is ready to send.
    
    ***************************************************************************/
    
    private void[][2] array;

    private uint array_index;

    /***************************************************************************

        Process a single array, sending it to the output delegate.
        
        Params:
            output = output delegate
            array  = array to process
    
    ***************************************************************************/

    public void processArray ( RequestParams.GetPairDg output, uint id, void[] array )
    {
        this.array[this.array_index].length = array.length;
        this.array[this.array_index][] = array[];

        this.array_index++;

        if ( this.array_index == 2 )
        {
            this.array_index = 0;
            
            output(id, cast(char[])this.array[0], cast(char[])this.array[1]);
        }
    }
    

    /***************************************************************************

        Reset.
    
    ***************************************************************************/
    
    override public void reset ( )
    {
        this.array_index = 0;
        this.array[0].length = 0;
        this.array[1].length = 0;
    }
}

