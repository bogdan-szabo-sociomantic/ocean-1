/******************************************************************************

    LZO1X-1 (Mini LZO) compressor/uncompressor generating/accepting chunks of
    compressed data with a length and checksum header 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    LZO chunk data layout if size_t has a width of 32-bit:
        void[] chunk
        
        chunk[0 .. 17] - header
        chunk[17 .. $] - compressed data
        
        Header data layout:
            chunk[0  ..  4] - length of chunk[4 .. $] (or compressed data length
                              + header length - 4)
            chunk[4 ..   8] - 32-bit CRC value of following header elements and
                              compressed data (chunk[8 .. $]), calculated using
                              lzo_crc32()
            chunk[8  .. 13] - algorithm identifier, e.g. "LZO1X"
            chunk[13 .. 17] - length of uncompressed data
            
 ******************************************************************************/

module ocean.io.compress.minilzo.LzoChunk;

/******************************************************************************

    Imports
    
******************************************************************************/

private import ocean.io.compress.minilzo.MiniLzo;

private import ocean.core.Exception: CompressException, assertEx;

private import tango.util.log.Trace;

/******************************************************************************

    LzoChunk class

 ******************************************************************************/

class LzoChunk
{
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
        
        this.data = new void[Header.length + this.lzo.maxCompressedLength(data_size)];
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
        this.data.length = Header.length + this.lzo.maxCompressedLength(uncompressed.length);
        
        size_t end = Header.length + this.lzo.compress(uncompressed, this.data[Header.length .. $]);
        
        this.data.length = end;
        
        return Header.write(this.data, data.length);
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
        size_t uncompressed_length;
        
        void[] compressed = Header.read(chunk, uncompressed_length);
        
        this.data.length = uncompressed_length;
        
        this.lzo.decompress(compressed, this.data);
        
        return this.data;
    }
    
    /**************************************************************************
    
        Destructor
         
     **************************************************************************/

    ~this ( )
    {
        delete this.lzo;
        delete this.data;
    }
    
    /**************************************************************************
    
        Calculates the sum of the sizes of the types of T
         
     **************************************************************************/

    template SizeofTuple ( T ... )
    {
        static if (T.length > 1)
        {
            const SizeofTuple = T[0].sizeof + SizeofTuple!(T[1 .. $]);
        }
        else
        {
            const SizeofTuple = T[0].sizeof;
        }
    }

    /**************************************************************************
    
        Header structure
         
     **************************************************************************/

    align (1) struct Header
    {
        /**********************************************************************
            
            Length of the chunk excluding this length value
             
         **********************************************************************/
        
        size_t chunk_length;
        
        /**********************************************************************
        
            CRC32 of compressed data
             
         **********************************************************************/
        
        uint crc32;
        
        /**********************************************************************
        
            Algorithm identifier. AlgoId is defined below
             
         **********************************************************************/
        
        char[5] algo_id = AlgoId;
        
        /**********************************************************************
        
            Length of uncompressed data
             
         **********************************************************************/
        
        size_t uncompressed_length;
        
        /**********************************************************************
        
            Identifer of LZO algorithm used
             
         **********************************************************************/
    
        const AlgoId = "LZO1X";
        
        /**********************************************************************
        
            Total data length of the members of this structure. With "align (1)"
            as structure definition attribute "length" equals the "sizeof" value
            since the member data are then packed without padding.
            Because this structure represents the LZO chunk header data
            elements, "length" must equal "sizeof" in order to generate the
            correct LZO chunk header by serializing an instance of this
            structure. Hence "length == sizeof" is checked at ccompile-time
            in write(). 
             
         **********************************************************************/

        const length = SizeofTuple!(typeof (typeof (*this).tupleof));
        
        /**********************************************************************
        
            Sets the header elements according to compressed and
            uncompressed_length.
            
            Params:
                compressed          = compressed data
                uncompressed_length = data length before compression 
             
            Returns:
                this instance
             
         **********************************************************************/

        typeof (this) set ( void[] compressed, size_t uncompressed_length )
        {
            this.chunk_length = compressed.length + this.length - typeof (this.chunk_length).sizeof;
            
            this.uncompressed_length = uncompressed_length;
            
            this.crc32 = MiniLzo.crc32(this.crc32OfElements(), compressed);
            
            return this;
        }
        
        /**********************************************************************
        
            Writes the header to chunk[0 .. this.length].
            
            Params:
                chunk = LZO chunk without header
             
            Returns:
                chunk (passed through)
             
            Throws:
                CompressException if chunk is shorter than this.length
             
         **********************************************************************/

        void[] write ( void[] chunk )
        {
            static assert (typeof (*this).sizeof == this.length, typeof (*this).stringof ~ ": bad data alignment");
            
            assertEx!(CompressException)(chunk.length >= this.length, "LZO chunk too short too write a header");
            
            *(cast (typeof (this)) chunk.ptr) = *this; 
            
            return chunk;
        }
        
        /**********************************************************************
        
            Reads the header from chunk and sets the members of this instance to
            the values contained in the header.
            
            Params:
                chunk = LZO chunk with header
             
            Returns:
                this instance
             
            Throws:
                CompressException if chunk is shorter than this.length
                
         **********************************************************************/

        typeof (this) read ( void[] chunk )
        {
            assertEx!(CompressException)(chunk.length >= this.length, "LZO chunk too short too read a header");
            
            *this = *(cast (typeof (this)) chunk.ptr);
            
            return this;
        }
        
        /**********************************************************************
        
            Checks if the member values of this instance are correct and
            consistent with the compressed data.
            
            Params:
                compressed = compressed data
             
            Returns:
                compressed data (passed through)
             
            Throws:
                CompressException if one of the following conditions is not
                satisfied:
                    1. compressed.length is not equal to
                       this.chunk_length - header length
                    2. The algorithm ID does not match this.AlgoId
                    3. The compressed data lenght exceeds the possible maximum 
                       compressed data length calculated from
                       this.uncompressed_length
                    4. The 32-bit CRC value calculated from compressed does not
                       equal this.crc32
                
         **********************************************************************/

        void[] check ( void[] compressed )
        {
            assertEx!(CompressException)(compressed.length == this.chunk_length - this.length + typeof (this.chunk_length).sizeof,
                                         "LZO chunk size mismatch");
            
            assertEx!(CompressException)(this.algo_id == this.AlgoId,
                                         "Wrong algorithm in LZO chunk header");
            
            assertEx!(CompressException)(this.uncompressed_length <= MiniLzo.maxCompressedLength(compressed.length),
                                         "LZO compressed data too long");
            
            assertEx!(CompressException)(this.crc32 == MiniLzo.crc32(this.crc32OfElements(), compressed),
                                         "LZO chunk data corrupted (CRC32 mismatch)");
            
            return compressed;
        }
        
        /**********************************************************************
        
            Sets the header elements according to chunk and uncompressed_length
            and writes the header to chunk[0 .. this.length].
            chunk[this.length .. $] contains compressed data whose
            length was uncompressed_length before compression.
            
            Params:
                chunk               = LZO chunk without header
                uncompressed_length = data length before compression
             
            Returns:
                chunk (passed through)
             
             Throws:
                CompressException if chunk is shorter than this.length
             
         **********************************************************************/

        static void[] write ( void[] chunk, size_t uncompressed_length )
        {
            typeof (*this) header;
            
            return header.set(chunk[this.length .. $], uncompressed_length).write(chunk);
        }
        
       /**********************************************************************
       
           Strips the header from chunk and checks if the header element values
           of this instance are correct and consistent with the compressed data.
           
           Params:
               chunk = LZO chunk with header
            
           Returns:
               compressed data (slice of chunk)
            
           Throws:
                CompressException if one of the following conditions is not
                satisfied:
                    1. chunk is shorter than this.length
                    2. compressed.length is not equal to
                       this.chunk_length - header length
                    3. The algorithm ID does not match this.AlgoId
                    4. The compressed data lenght exceeds the possible maximum 
                       compressed data length calculated from
                       this.uncompressed_length
                    5. The 32-bit CRC value calculated from compressed does not
                       equal this.crc32
               
        **********************************************************************/

        static void[] read ( void[] chunk, out size_t uncompressed_length )
        {
            typeof (*this) header;
            
            scope (success) uncompressed_length = header.uncompressed_length;
            
            return header.read(chunk).check(chunk[this.length .. $]);
        }
        
        /**********************************************************************
        
            Calculates the CRC32 value of the header elements after crc32. 
                
         **********************************************************************/

        uint crc32OfElements ( )
        {
            return MiniLzo.crc32((cast (void*) this)[this.crc32.offsetof + this.crc32.sizeof .. this.length]);
        }
    }
}