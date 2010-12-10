/*******************************************************************************

    Chunk source which reads array chunks from a buffer

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.source.BufferChunkSource;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.source.model.IChunkSource;

private import tango.util.log.Trace;

/*******************************************************************************

    Chunk source which reads array chunks from a buffer

*******************************************************************************/

template BufferChunkSource ( T )
{
    static assert (T.sizeof == char.sizeof, "BufferChunkSource: single byte data "
                   "array base type required, not '" ~ T.stringof ~ '\'');
     
    class BufferChunkSource : IChunkSource!(T[]*)
    {
        /***************************************************************************
    
            Read position through the input buffer
        
        ***************************************************************************/
    
        private size_t array_cursor;
        
        override void reset ( )
        {
            super.reset();
            
            this.array_cursor = 0;
        }
        
        /***************************************************************************
        
            Reads the length of the next array from the input source.
        
            Params:
                input = next input array
                
            Returns:
                length of next array
        
        ***************************************************************************/
    
        public size_t readArrayLength ( hash_t id, T[]* input )
        {
            return input.length;
        }
    
    
        /***************************************************************************
        
            Populates chunk with data from input, starting at the current
            position.
        
            Params:
                input = input array
                chunk = chunk destination buffer
        
        ***************************************************************************/

        public void getNextChunk ( hash_t id, T[]* input, void[] chunk )
        in
        {
            assert (this.array_cursor + chunk.length <= (*input).length,
                    typeof (this).stringof ~ ".getNextChunk: chunk too long");
        }
        body
        {
            size_t end = this.array_cursor + chunk.length;
            
            chunk[] = cast (void[]) (*input)[this.array_cursor .. end];
            
            this.array_cursor = end;
        }
    
    
        /***************************************************************************
        
            Tells whether an array is the end of a list.
            
            Params:
                input = input array (unused, demanded by abstract super class
                        method)
                array = array currently being processed
        
            Returns:
                true if the array being processed is the end of a list
        
        ***************************************************************************/
    
        public bool endOfList ( T[]* input, void[] array )
        {
            return array.length == 0;
        }
    }

}