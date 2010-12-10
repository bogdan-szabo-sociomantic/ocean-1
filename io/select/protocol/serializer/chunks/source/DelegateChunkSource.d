/*******************************************************************************

    Chunk source which reads array chunks from a delegate
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        September 2010: Initial release
    
    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.source.DelegateChunkSource;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.source.model.IChunkSource;

private import ocean.io.request.params.RequestParams;

private import ocean.core.Array;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Chunk source which reads array chunks from a delegate

*******************************************************************************/

class DelegateChunkSource : IChunkSource!(RequestParams.PutValueDg)
{
    /***************************************************************************

        Internal copy of the array fetched from the delegate 
   
    ***************************************************************************/

    private char[] array;


    /***************************************************************************

        Read position through the input buffer
    
    ***************************************************************************/

    private size_t array_cursor;
    
    override void reset ( )
    {
        super.reset();

        this.array.length = 0;
        this.array_cursor = 0;
    }


    /***************************************************************************
    
        Reads the length of the next array from the input source.

        The input delegate is called at this point, and the provided string is
        copied and stored internally to this class.
    
        Params:
            input = delegate to get an array
            
        Returns:
            length of array
    
    ***************************************************************************/

    public size_t readArrayLength ( hash_t id, RequestParams.PutValueDg input )
    {
        this.array.copy(input(id));
        return this.array.length;
    }


    /***************************************************************************
    
        Populates chunk with data from input, starting at the current position.
    
        Params:
            input = delegate to get an array (unused, demanded by abstract super
                    class method)
            chunk = chunk destination buffer
    
    ***************************************************************************/

    public void getNextChunk ( hash_t id, RequestParams.PutValueDg input, void[] chunk )
    in
    {
        assert (this.array_cursor + chunk.length <= this.array.length,
                typeof (this).stringof ~ ".getNextChunk: chunk too long");
    }
    body
    {
        size_t end = this.array_cursor + chunk.length;
        
        chunk[] = cast (void[]) this.array[this.array_cursor .. end];

        this.array_cursor = end;
    }


    /***************************************************************************
    
        Tells whether an array is the end of a list.
        
        Params:
            input = delegate to get an array (unused, demanded by abstract super
                    class method)
            array = array currently being processed
    
        Returns:
            true if the array being processed is the end of a list
    
    ***************************************************************************/

    public bool endOfList ( RequestParams.PutValueDg input, void[] array )
    {
        return array.length == 0;
    }
}
