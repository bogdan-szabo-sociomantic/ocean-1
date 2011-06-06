/*******************************************************************************

    Class encapsulating an lzo chunk compressor and a memory buffer to store
    de/compression results.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        February 2011: Initial release

    authors:        Gavin Norman

*******************************************************************************/

module ocean.io.compress.lzo.LzoChunkCompressor;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.compress.Lzo;

private import ocean.io.compress.lzo.LzoChunk;

private import ocean.io.compress.lzo.LzoHeader;

debug private import tango.util.log.Trace;



/*******************************************************************************

    Lzo chunk compressor

*******************************************************************************/

class LzoChunkCompressor
{
    /***************************************************************************

        Constants defining whether de/compression headers expect the chunk
        length to be stored inline (ie as part of the chunk array).

    ***************************************************************************/

    static private const bool DecompressLenghtInline = false;
    static private const bool CompressLenghtInline = true;


    /***************************************************************************

        Chunk decompressor.
    
    ***************************************************************************/

    public class Decompressor
    {
        /***********************************************************************

            Aliases for the lzo header & chunk.
        
        ***********************************************************************/

        public alias LzoHeader!(DecompressLenghtInline) Header;
        public alias LzoChunk!(DecompressLenghtInline) Chunk;


        /***********************************************************************

            Lzo chunk instance, used to do the decompression.
        
        ***********************************************************************/

        private Chunk chunk;


        /***********************************************************************

            Constructor.
        
        ***********************************************************************/

        public this ( )
        {
            this.chunk = new Chunk(this.outer.lzo);
        }


        /***********************************************************************

            Decompresses provided data.
            
            Params:
                source = data to decompress

            Returns:
                decompressed data (a slice into the outer class' results buffer)
        
        ***********************************************************************/

        public void[] decompress ( void[] source )
        {
            this.chunk.uncompress(source, this.outer.result);
            return this.outer.result;
        }


        /***********************************************************************

            Tells whether the provided data is an lzo start chunk.

            Params:
                source = data to check
    
            Returns:
                true if data is an lzo start chunk
        
        ***********************************************************************/

        public bool isStartChunk ( void[] array )
        {
            Header header;

            if ( array.length < header.read_length )
            {
                return false;
            }
            else
            {
                return header.tryReadStart(array[0..header.read_length]);
            }
        }
    }


    /***************************************************************************

        Chunk compressor.
    
    ***************************************************************************/

    public class Compressor
    {
        /***********************************************************************

            Aliases for the lzo header & chunk.
        
        ***********************************************************************/

        public alias LzoHeader!(CompressLenghtInline) Header;
        public alias LzoChunk!(CompressLenghtInline) Chunk;


        /***********************************************************************

            Lzo chunk instance, used to do the compression.
        
        ***********************************************************************/

        private Chunk chunk;


        /***********************************************************************

            Constructor.
        
        ***********************************************************************/

        public this ( )
        {
            this.chunk = new Chunk(this.outer.lzo);
        }


        /***********************************************************************

            Compresses provided data.
            
            Params:
                source = data to compress
    
            Returns:
                compressed data (a slice into the outer class' results buffer)

        ***********************************************************************/

        public void[] compress ( void[] source )
        {
            this.chunk.compress(source, this.outer.result);
            return this.outer.result;
        }


        /***********************************************************************

            Tells whether the provided data is an lzo start chunk.
    
            Params:
                source = data to check
    
            Returns:
                true if data is an lzo start chunk
        
        ***********************************************************************/

        public bool isStartChunk ( void[] array )
        {
            Header header;

            if ( array.length < header.read_length )
            {
                return false;
            }
            else
            {
                return header.tryReadStart(array[0..header.read_length]);
            }
        }
    }


    /***************************************************************************

        Chunk de/compressor instances.
    
    ***************************************************************************/

    public Decompressor decompressor;
    public Compressor compressor;


    /***************************************************************************

        Internal lzo object.
    
    ***************************************************************************/

    private Lzo lzo;


    /***************************************************************************

        Internal de/compression results buffer.
    
    ***************************************************************************/

    private void[] result;


    /***************************************************************************

        Constructor.
    
    ***************************************************************************/

    public this ( )
    {
        this.lzo = new Lzo;

        this.compressor = new Compressor;
        this.decompressor = new Decompressor;
    }


    /***************************************************************************

        Destructor.
    
    ***************************************************************************/

    ~this ( )
    {   
        this.result.length = 0;
    }
}

