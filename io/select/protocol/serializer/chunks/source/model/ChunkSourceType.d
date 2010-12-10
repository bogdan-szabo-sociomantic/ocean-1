/*******************************************************************************

    Array chunk source templates
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman & David Eckardt
    
    Templates to select a specific IChunkSource subclass by input type
    
*******************************************************************************/

module dht.async.select.protocol.serializer.chunks.source.model.ChunkSource;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.request.params.RequestParams;

private import ocean.io.select.protocol.serializer.chunks.source.model.IChunkSource,
               ocean.io.select.protocol.serializer.chunks.source.StreamChunkSource,
               ocean.io.select.protocol.serializer.chunks.source.DelegateChunkSource,
               ocean.io.select.protocol.serializer.chunks.source.BufferChunkSource,
               ocean.io.select.protocol.serializer.chunks.source.ListChunkSource;

/***************************************************************************

    Evaluates to an array source class appropriate to the passed input chunk
    type.
    
    Template params:
        Input = type of input data source
    
    Evaluates to:
        array source class

***************************************************************************/

template ChunkSourceType ( Input )
{
    static if ( is(Input T == T[]*) )
    {
        static if ( is(T U == U[]) )
        {
            alias ListChunkSource!(U) ChunkSourceType;
        }
        else
        {
            alias BufferChunkSource!(T) ChunkSourceType;
        }
    }
    else static if ( is(Input == RequestParams.PutValueDg) )
    {
        alias DelegateChunkSource ChunkSourceType;
    }
    else
    {
        static assert(is(Input == InputStream), typeof(this).stringof ~ " - unhandled array source type: " ~ Input.stringof );
        
        alias StreamChunkSource ChunkSourceType;
    }
}
