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

private import ocean.io.request.params.RequestParams;

private import ocean.io.select.protocol.serializer.chunks.dest.StreamChunkDest,
               ocean.io.select.protocol.serializer.chunks.dest.BufferChunkDest,
               ocean.io.select.protocol.serializer.chunks.dest.ValueDelegateChunkDest,
               ocean.io.select.protocol.serializer.chunks.dest.PairDelegateChunkDest;

private import tango.io.model.IConduit: OutputStream;



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
    
        static if (is(Output == RequestParams.GetValueDg) )
        {
            alias ValueDelegateChunkDest ChunkDestType;
        }
        else static if (is(Output == RequestParams.GetPairDg) )
        {
            alias PairDelegateChunkDest ChunkDestType;
        }
        else static if ( is(Output T == T[]*) )
        {
            alias BufferChunkDest!(T) ChunkDestType;
        }
        else
        {
            static assert(is(Output == OutputStream), "ChunkDestType - unhandled array destination type: " ~ Output.stringof );
            
            alias StreamChunkDest ChunkDestType;
        }
}

