/******************************************************************************

    LZO1X-1 (Mini LZO) compressor/uncompressor generating/accepting chunks of
    compressed data with a length and checksum header 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    Chunk data layout if size_t has a width of 32-bit:
        void[] chunk
        
        chunk[0 .. 16] - header
        chunk[16 .. $] - compressed data
        
        Header data layout:
            chunk[0  ..  4] - length of chunk[4 .. $] (or compressed data length
                              + header length - 4)
            chunk[4 ..   8] - 32-bit CRC value of following header elements and
                              compressed data (chunk[8 .. $]), calculated using
                              lzo_crc32()
            chunk[8  .. 12] - chunk/compression type code (signed 32-bit integer)
            chunk[12 .. 16] - length of uncompressed data
            
 ******************************************************************************/

module ocean.io.compress.minilzo.LzoChunk;

/******************************************************************************

    Imports
    
******************************************************************************/

private import ocean.io.compress.minilzo.MiniLzo;

private import ocean.io.compress.CompressionHeader;

private import ocean.core.Exception: CompressException, assertEx;

private import tango.util.log.Trace;

/******************************************************************************

    LzoChunk class

 ******************************************************************************/

class LzoChunk
{
    alias MiniLzo.maxCompressedLength maxCompressedLength;
    
    /**************************************************************************
    
        MiniLzo instance
         
     **************************************************************************/

    private MiniLzo lzo;
    
    /**************************************************************************
    
        Data buffer
         
     **************************************************************************/

    private void[] data;
    
    /**************************************************************************
    
        Constructor
        
        Params:
            data_size = expected uncompressed data size (optional, for
                        preallocation)
         
     **************************************************************************/

    public this ( size_t data_size = 0 )
    {
        this.lzo = new MiniLzo;
        
        this.data = new void[CompressionHeader.length + this.maxCompressedLength(data_size)];
    }
    
    /**************************************************************************
    
        Compresses a data chunk 
        
        Params:
            uncompressed = data chunk to compress
            
        Returns:
            LZO chunk containing compressed data
         
     **************************************************************************/

    public void[] compress ( void[] uncompressed )
    {
        CompressionHeader header;
        
        size_t end;
        
        header.uncompressed_length = uncompressed.length;
        header.type                = header.type.LZO1X;
        
        this.data.length = header.length + this.maxCompressedLength(uncompressed.length);
        
        end = header.length + this.lzo.compress(uncompressed, header.strip(this.data));
        
        this.data.length = end;
        
        return header.write(this.data);
    }
    
    public size_t compress ( void[] uncompressed, void[] chunk )
    {
        CompressionHeader header;
        
        size_t end = header.length + this.lzo.compress(uncompressed, header.strip(chunk));
        
        header.uncompressed_length = uncompressed.length;
        header.type                = header.type.LZO1X;
        
        header.write(chunk[0 .. end]);
        
        return end;
    }
    
    /**************************************************************************
    
        Uncompresses a LZO chunk 
        
        Params:
            chunk = LZO chunk to uncompress
            
        Returns:
            uncompressed data chunk
         
     **************************************************************************/

    public void[] uncompress ( void[] chunk )
    {
        CompressionHeader header;
        
        void[] compressed = header.read(chunk);
        
        this.data.length = header.uncompressed_length;
        
        assertEx!(CompressException)(header.type == header.type.LZO1X, "Not LZO1X");
        
        this.lzo.decompress(compressed, this.data);
        
        return this.data;
    }
    
    /+
    /******************************************************************************

        Calculates the maximum compressed length of data which has a length of
        uncompressed_length.
        
        Note: Surprisingly, this is more than uncompressed_length but that's the
              worst case for completely uncompressable data.
    
        Parameters:
            uncompressed_length = length of data to compressed
            
        Returns:
            maximum compressed length of data
    
     ******************************************************************************/
    
    static size_t maxCompressedLength ( size_t uncompressed_length )
    {
        return MiniL(uncompressed_length);
    }
    +/

    /**************************************************************************
    
        Destructor
         
     **************************************************************************/

    ~this ( )
    {
        delete this.lzo;
        delete this.data;
    }
}