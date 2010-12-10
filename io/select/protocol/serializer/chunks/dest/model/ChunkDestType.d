/*******************************************************************************

    Array chunk destination templates
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman & David Eckardt
    
    Templates to select a specific IChunkDest subclass by input type

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.dest.model.ChunkDestType;



/******************************************************************************

    Imports

******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.ChunkDelegates;

private import ocean.io.select.protocol.serializer.chunks.dest.ValueDelegateChunkDest,
               ocean.io.select.protocol.serializer.chunks.dest.PairDelegateChunkDest;



/******************************************************************************

    ChunkDest struct: merely a namespace

 ******************************************************************************/

template ChunkDestType ( Output )
{
    /***************************************************************************
    
        Evaluates to an array dest class appropriate to the passed output chunk
        type.
        
        Template params:
            Output = type of output data destination
        
        Evaluates to:
            array destination class
    
    ***************************************************************************/
    
    static if (is(Output == ChunkDelegates.GetValueDg) )
    {
        alias ValueDelegateChunkDest ChunkDestType;
    }
    else static if (is(Output == ChunkDelegates.GetPairDg) )
    {
        alias PairDelegateChunkDest ChunkDestType;
    }
    else
    {
        static assert(false, "ChunkDestType - unhandled array destination type: " ~ Output.stringof );
    }
}

