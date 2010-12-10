/*******************************************************************************

    Array chunk serializer templates
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman & David Eckardt
    
    Template to select a specific IChunkSerializer subclass by compression
    template parameter
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.model.ChunkSerializerType;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.CompressedChunkSerializer,
               ocean.io.select.protocol.serializer.chunks.ChunkSerializer;


/***************************************************************************

    Evaluates to a chunk serializer class based on the compression template
    argument.
    
    Template params:
        Compressed = write compressed chunks
    
    Evaluates to:
        chunk serializer class

***************************************************************************/

template ChunkSerializerType ( bool Compressed = false )
{
    static if ( Compressed )
    {
        alias CompressedChunkSerializer ChunkSerializerType;
    }
    else
    {
        alias ChunkSerializer ChunkSerializerType;
    }
}