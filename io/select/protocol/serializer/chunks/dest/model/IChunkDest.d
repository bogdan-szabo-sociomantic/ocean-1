/*******************************************************************************

    Array chunk destination. Abstract class receiving a series of arrays to a
    variety of destinations.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.dest.model.IChunkDest;


/*******************************************************************************

    Chunk destination abstract base class

    Template params:
        Output = type of output destination

*******************************************************************************/

abstract class IChunkDest ( Output )
{
    /***************************************************************************

        Process a single array, writing it to the output destination.
        
        Params:
            output = output destination (buffer/stream/callback delegate)
            array  = array to process
    
    ***************************************************************************/

    abstract public void processArray ( Output output, void[] array );


    /***************************************************************************

        Called before processing begins. Default does nothing, but derived
        classes may need to implement special behaviour here.
        
        Attention: this.output may be null when this method is called.
        
    ***************************************************************************/

    public void reset ( )
    {
    }
}

