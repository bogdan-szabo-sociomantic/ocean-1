/******************************************************************************

    Generates and reads headers of chunks of compressed data, containing the
    data length, compression type and checksum 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
    
    CompressionHeader data layout if size_t has a width of 32-bit:
        void[16] header
        
            header[0  ..  4] - length of chunk[4 .. $] (or compressed data
                               length + header length - 4)
            header[4 ..   8] - 32-bit CRC value of following header elements and
                               compressed data (chunk[8 .. $]), calculated using
                               lzo_crc32()
            header[8  .. 12] - chunk/compression type code (signed integer)
            header[12 .. 16] - length of uncompressed data (may be 0)
            
 ******************************************************************************/

module ocean.io.compress.CompressionHeader;

private import ocean.io.compress.minilzo.LzoCrc;

private import ocean.core.Exception: CompressException, assertEx;

//private import tango.util.log.Trace;

/******************************************************************************

    CompressionHeader structure
 
 ******************************************************************************/

align (1) struct CompressionHeader
{
    /**************************************************************************
        
        Length of the chunk excluding this length value
        
        The default value is that of a payload-less chunk (start/stop chunk).
        
        "length" constant is defined below
        
     **************************************************************************/
    
    size_t chunk_length = length - size_t.sizeof;
    
    /**************************************************************************
    
        CRC32 of following header elements and compressed data
         
     **************************************************************************/
    
    private uint crc32_;
    
    /**************************************************************************
    
        Chunk type (Type enumerator is defined below)
         
     **************************************************************************/
    
    Type type = Type.None;
    
    /**************************************************************************
    
        Length of uncompressed data
         
     **************************************************************************/
    
    size_t uncompressed_length = 0;
    
    /**************************************************************************
    
        Error message source constant
         
     **************************************************************************/
    
    const ErrMsgSource = typeof (*this).stringof;
    
    /**************************************************************************
    
        Header type enumerator
         
     **************************************************************************/
    
    enum Type : int
    {
        None = 0,
        LZO1X,
        
        Start = -1,
        Stop  = -2
    }

    /**************************************************************************
    
        Total data length of the members of this structure. With "align (1)"
        as structure definition attribute "length" equals the "sizeof" value
        since the member data are then packed without padding.
        Because this structure represents the LZO chunk header data
        elements, "length" must equal "sizeof" in order to generate the
        correct LZO chunk header by serializing an instance of this
        structure. Hence "length == sizeof" is checked at ccompile-time
        in write(). 
         
     **************************************************************************/
    
    const length = SizeofTuple!(typeof (this.tupleof));
    
    pragma (msg, length.stringof);
    
    /**************************************************************************
    
        Writes the header to chunk[0 .. this.length].
        
        Params:
            chunk = chunk without header
         
        Returns:
            chunk (passed through)
         
        Throws:
            CompressException if chunk is shorter than this.length
         
     **************************************************************************/
    
    void[] write ( void[] chunk )
    {
        static assert ((*this).sizeof == this.length,
                       this.ErrMsgSource ~ ": Bad data alignment");
        
        assertEx!(CompressException)(chunk.length >= this.length,
                                     this.ErrMsgSource ~ ": Chunk too short to write header");
        
        this.chunk_length = chunk.length - this.chunk_length.sizeof;
        
        this.crc32_ = this.crc32(this.strip(chunk));
        
        *(cast (typeof (this)) chunk.ptr) = *this; 
        
        return chunk;
    }
    
    /**************************************************************************
    
        Sets this instance to create a header for a chunk containing
        uncompressed data. Compression method is set to None.
        
        Params:
            payload = data to create header for
         
        Returns:
            header data
         
        Throws:
            CompressException if chunk is shorter than this.length
         
     **************************************************************************/

    void[] uncompressed ( void[] payload )
    {
        this.type = this.type.None;
        
        this.uncompressed_length = payload.length;
        
        this.chunk_length += payload.length;
        
        this.crc32_ = this.crc32(payload);
        
        return this.data;
    }
    
    /**************************************************************************
    
        Sets this instance to create a Start header. Since a Start chunk has no
        payload, the returned data are a full Start chunk.
        
        Params:
            total_uncompressed_length = total uncompressed length of data
                                        contained in the following chunks
         
        Returns:
            Start header/chunk data
         
     **************************************************************************/

    void[] start ( size_t total_uncompressed_length )
    {
        *this = typeof (*this).init;
        
        this.type = this.type.Start;
        
        this.uncompressed_length = total_uncompressed_length;
        
        this.crc32_ = this.crc32();
        
        return this.data;
    }
    
    /**************************************************************************
    
        Sets this instance to create a Stop header. Since a Stop chunk has no
        payload, the returned data are a full Start chunk.
        
        Returns:
            Stop header/chunk data
         
     **************************************************************************/

    void[] stop ( )
    {
        *this = typeof (*this).init;
        
        this.type = this.type.Stop;
        
        this.crc32_ = this.crc32();
        
        return this.data;
    }
    
    /**************************************************************************
        
        Returns the header data of this instance.
        
        Returns:
            header data of this instance
         
     **************************************************************************/
    
    void[] data ( )
    {
        return (cast (void*) this)[0 .. this.length];
    }
    
    /**************************************************************************
        
        Returns the header data of tihs instance without the leading chunk
        length value.
        
        Returns:
            header data of tihs instance without the leading chunk length value
         
     **************************************************************************/

    void[] data_without_length ( )
    {
        return (cast (void*) this)[size_t.sizeof .. this.length];
    }
    
    /**************************************************************************
    
        Reads the header from chunk and sets the members of this instance to
        the values contained in the header.
        
        Params:
            chunk = LZO chunk with header
         
        Returns:
            this instance
         
        Throws:
            CompressException if chunk is shorter than this.length
            
     **************************************************************************/
    
    void[] read ( void[] chunk )
    {
        void[] payload = this.strip(chunk);
        
        *this = *(cast (typeof (this)) chunk.ptr);
        
        assertEx!(CompressException)(chunk.length == this.chunk_length + this.chunk_length.sizeof,
                                     this.ErrMsgSource ~ ": Chunk length mismatch");
        
        assertEx!(CompressException)(this.crc32_ == this.crc32(payload),
                                     this.ErrMsgSource ~ ": Chunk data corrupted (CRC32 mismatch)");
        
        return payload;
    }
    
    /**************************************************************************
    
        Calculates the CRC32 value of the header elements after crc32. 
            
     **************************************************************************/
    
    uint crc32 ( void[] payload = null )
    {
        uint crc32 = LzoCrc.crc32((cast (void*) this)[this.crc32_.offsetof + this.crc32_.sizeof .. this.length]);
        
        if (payload)
        {
            crc32 = LzoCrc.crc32(crc32, payload);
        }
        
        return crc32;
    }
    
    /**************************************************************************
    
        Strips the header from chunk
        
        Params:
            chunk: chunk with header
        
        Returns:
            chunk data after header (slice to chunk)
        
     **************************************************************************/

    static void[] strip ( void[] chunk )
    {
        assertEx!(CompressException)(chunk.length >= this.length,
                                     this.ErrMsgSource ~ ": Chunk too short to strip header");
        
        return chunk[this.length .. $];
    }
}

/******************************************************************************

    Calculates the sum of the sizes of the types of T
 
 ******************************************************************************/

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

