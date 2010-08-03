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
            chunk = LZO chunk without header
         
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
        
//        this.crc32 = LzoCrc.crc32(this.crc32OfElements(), this.strip(chunk));
        
        this.chunk_length = chunk.length - this.chunk_length.sizeof;
        
        this.crc32_ = this.crc32(this.strip(chunk));
        
//        Trace.formatln("write:\n\tchunk.length = {}\n\tthis.chunk_length = {}", this.chunk_length, this.uncompressed_length);
        
        *(cast (typeof (this)) chunk.ptr) = *this; 
        
        return chunk;
    }
    
    void[] uncompressed ( void[] payload )
    {
        this.type = this.type.None;
        
        this.uncompressed_length = payload.length;
        
        this.chunk_length += payload.length;
        
        this.crc32_ = this.crc32(payload);
        
        return this.data;
    }
    
    void[] start ( size_t total_uncompressed_length )
    {
        *this = typeof (*this).init;
        
        this.type = this.type.Start;
        
        this.uncompressed_length = total_uncompressed_length;
        
        this.crc32_ = this.crc32();
        
        return this.data;
    }
    
    void[] stop ( )
    {
        *this = typeof (*this).init;
        
        this.type = this.type.Stop;
        
        this.crc32_ = this.crc32();
        
        return this.data;
    }
    
    void[] data ( )
    {
        return (cast (void*) this)[0 .. this.length];
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

