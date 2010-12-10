/*******************************************************************************

    Array chunk source. Abstract class serving a series of arrays from a variety
    of sources.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module dht.async.select.protocol.serializer.chunks.source.model.IChunkSource;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.model.IConduit: InputStream;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Array chunk source abstract base class. Arrays are read from the source one
    at a time, as follows:
    
        1. The total array length is read
        2. A series of chunks are extracted from the array for processing.

    Template params:
        Input = type of input source

*******************************************************************************/

abstract class IChunkSource ( Input )
{
    /***************************************************************************
    
        Count of arrays processed
    
    ***************************************************************************/

    public uint arrays_processed;


    /***************************************************************************
    
        Reads the length of the next array from the input source.
    
        Params:
            input = input source (buffer/list/stream)
            
        Returns:
            length of next array
    
    ***************************************************************************/

    abstract public size_t readArrayLength ( Input input );


    /***************************************************************************
    
        Reads a chunk of content from the input source.
    
        Params:
            input = input source (buffer/list/stream)
            chunk = chunk destination buffer
    
    ***************************************************************************/

    abstract public void getNextChunk ( Input input, void[] chunk );
    

    /***************************************************************************
    
        Tells whether an array is the end of a list.
        
        Params:
            input = input item (buffer/list/stream)
            array = array currently being processed

        Returns:
            true if the array being processed is the end of a list

    ***************************************************************************/

    abstract public bool endOfList ( Input input, void[] array );


    /***************************************************************************

        Resets internals.
    
    ***************************************************************************/
    
    public void reset ( )
    {
        this.arrays_processed = 0;
    }


    /***************************************************************************

        Advances the internal array counter. Called when processing of an array
        has been completed.

    ***************************************************************************/

    public void nextArray ( )
    {
        this.arrays_processed++;
    }
}

