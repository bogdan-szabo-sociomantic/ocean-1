/*******************************************************************************

    LZO1X-1 (Mini LZO) compressor/uncompressor generating/accepting chunks of
    compressed data with a length and checksum header 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
            
 ******************************************************************************/

module ocean.io.compress.lzochunk.LzoChunk;

/*******************************************************************************

    Imports
    
 ******************************************************************************/

private     import      ocean.io.compress.Lzo;

private     import      ocean.io.compress.lzochunk.CompressionHeader;

private     import      ocean.core.Exception: CompressException, assertEx;

private     import      tango.util.log.Trace;

/*******************************************************************************

    LzoChunk compressor/decompressor
    
    Chunk data layout if size_t has a width of 32-bit
    ---
    void[] chunk
    
    chunk[0 .. 16] - header
    chunk[16 .. $] - compressed data
    ---
    
    Header data layout
    --
    chunk[0  ..  4] - length of chunk[4 .. $] (or compressed data length
                      + header length - 4)
    chunk[4 ..   8] - 32-bit CRC value of following header elements and
                      compressed data (chunk[8 .. $]), calculated using
                      lzo_crc32()
    chunk[8  .. 12] - chunk/compression type code (signed 32-bit integer)
    chunk[12 .. 16] - length of uncompressed data
    ---
    
 ******************************************************************************/

class LzoChunk
{
    
    /***************************************************************************
    
        Lzo instance
         
     **************************************************************************/

    private             Lzo                     lzo;
    
    /***************************************************************************
    
        Input/output buffer
         
     **************************************************************************/

    private             void[]                      input;
    private             void[]                      output;
    
    /***************************************************************************
    
        Constructor
        
        Params:
            data_size = expected uncompressed data size (optional, for
                        preallocation)
         
     **************************************************************************/

    public this ( size_t data_size = 0 )
    {
        this.lzo   = new Lzo;
        
        this.input = new void[CompressionHeader.length + 
                     this.maxCompressedLength(data_size)];
    }
    
    /***************************************************************************
        
        Destructor
         
     **************************************************************************/
    
    ~this ( )
    {
        delete this.lzo;
        delete this.input;
        delete this.output;
    }

    /***************************************************************************
    
        Compresses a data chunk 
        
        Params:
            uncompressed = data chunk to compress
            
        Returns:
            LZO chunk containing compressed data
            
       	FIXME: move return parameter to ref (out) parameter
         
     **************************************************************************/

    public void[] compress ( void[] uncompressed )
    {
        CompressionHeader header;
        
        size_t end;
        
        header.uncompressed_length = uncompressed.length;
        header.type                = header.type.LZO1X;
        
        this.input.length = header.length + this.maxCompressedLength(uncompressed.length);
        
        end = header.length + this.lzo.compress(uncompressed, header.strip(this.input));
        
        this.input.length = end;
        
        return header.write(this.input);
    }
    
    public void compress ( void[] uncompressed, ref char[] output )
    {
        CompressionHeader header;
        
        size_t end;
        
        this.input.length = 0;
        
        char[] tmp;
             
        header.uncompressed_length = uncompressed.length;
        header.type                = header.type.LZO1X;
        
        this.input.length = header.length + this.maxCompressedLength(uncompressed.length);
        
        end = header.length + this.lzo.compress(uncompressed, header.strip(this.input));
        
        this.input.length = end;
        
        tmp = cast (char[]) header.write(this.input);
        
        output = tmp.dup;        
    }
    
    /***************************************************************************
    
        Uncompresses a LZO chunk 
        
        Params:
            chunk = LZO chunk to uncompress
            
        Returns:
            uncompressed data chunk
            
		FIXME: 	- move return parameter to ref (out) parameter
				- Add assertion for chunk length 
				- same method names in minilzo and lzochunk 
         
     **************************************************************************/

    public void[] uncompress ( void[] chunk )
    {
        CompressionHeader header;
        
        void[] compressed = header.read(chunk);
	        
	    this.output.length = header.uncompressed_length;
	
	    assertEx!(CompressException)(header.type == header.type.LZO1X, "Not LZO1X");
	        
	    this.lzo.decompress(compressed, this.output);
        
        return this.output;
    }
    
    /***************************************************************************
    
        Uncompresses a LZO chunk 
        
        Params:
            chunk = LZO chunk to uncompress            
            output = output parameter for the uncompressed result
            
        Returns:
            void
        
     **************************************************************************/
    
    public void uncompress ( void[] chunk, ref void[] output )
    {
        CompressionHeader header;
        
        void[] compressed = header.read(chunk);
            
        this.output.length = header.uncompressed_length;
    
        assertEx!(CompressException)(header.type == header.type.LZO1X, "Not LZO1X");
            
        this.lzo.decompress(compressed, this.output);
        
        output = this.output;
    }
    
    /***************************************************************************
    
        Static method alias, to be used as
        
                                                                             ---
        static size_t maxCompressedLength ( site_t uncompressed_length );
                                                                             ---
        
        Calculates the maximum compressed length of data which has a length of
        uncompressed_length.
        
        Note: Surprisingly, this is more than uncompressed_length but that's the
              worst case for completely uncompressable data.
    
        Parameters:
            uncompressed_length = length of data to compressed
            
        Returns:
            maximum compressed length of data
    
     **************************************************************************/
    
    alias Lzo.maxCompressedLength maxCompressedLength;
}