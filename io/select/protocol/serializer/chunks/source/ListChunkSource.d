/*******************************************************************************

    Chunk source which reads array chunks from a list of arrays

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        August 2010: Initial release
    
    authors:        Gavin Norman
    
*******************************************************************************/

module ocean.io.select.protocol.serializer.chunks.source.ListChunkSource;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.select.protocol.serializer.chunks.source.model.IChunkSource;

/*******************************************************************************

    Chunk source which reads array chunks from a list of arrays

*******************************************************************************/

template ListChunkSource ( T )
{
    class ListChunkSource : IChunkSource!(T[][]*)
    {
        static assert (T.sizeof == char.sizeof, "ListChunkSource: single byte data "
                       "array base type required, not '" ~ T.stringof ~ '\'');
         
    
        /***************************************************************************
    
            Read position through the current input array
        
        ***************************************************************************/
    
        private size_t array_cursor;
    
        /***************************************************************************
        
            Reads the length of the next array from the input source.
            
            Params:
                input = input array list
            
            Returns:
                length of next array
        
        ***************************************************************************/
    
        public size_t readArrayLength ( hash_t id, T[][]* input )
        {
            return (*input)[this.arrays_processed].length;
        }
        
    
        /***************************************************************************
        
            Reads a chunk of content from the current input list element.
        
            Params:
                input = input array list
                chunk = chunk destination buffer
            
        ***************************************************************************/
    
        public void getNextChunk ( hash_t id, T[][]* input, void[] chunk )
        in
        {
            assert (this.array_cursor + chunk.length <= (*input)[this.arrays_processed].length,
                    typeof (this).stringof ~ ".getNextChunk: chunk too long");
        }
        body
        {
            T[] array = (*input)[this.arrays_processed];
            
            size_t end = this.array_cursor + chunk.length;
            
            chunk[] = cast (void[]) array[this.array_cursor .. end];
            
            this.array_cursor = end;
        }
    
    
        /***************************************************************************
    
            Advances the internal array counter. Called when processing of an array
            has been completed.
            
            The internal read cursor is reset to 0, so the next array will be
            processed from the beginning.
        
        ***************************************************************************/
    
        override public void nextArray ( )
        {
            super.nextArray();
            this.array_cursor = 0;
        }
    
    
        /***************************************************************************
        
            Tells whether an array is the end of a list.
            
            Params:
                input = input array list
                array = array currently being processed
        
            Returns:
                true if the array being processed is the end of a list
        
        ***************************************************************************/
    
        public bool endOfList ( T[][]* input, void[] array )
        {
            return this.arrays_processed == input.length;
        }
    }

}