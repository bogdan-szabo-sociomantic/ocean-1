/******************************************************************************

    LZO1X-1 (Mini LZO) compressor/uncompressor 

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        July 2010: Initial release
    
    authors:        David Eckardt
            
 ******************************************************************************/

module ocean.io.compress.minilzo.Lzo;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.io.compress.lzochunk.c.minilzo: lzo1x_1_compress,
                                                     lzo1x_decompress, lzo1x_decompress_safe,
                                                     lzo1x_max_compressed_length, lzo_init,
                                                     Lzo1x1WorkmemSize, LzoStatus;

private import ocean.io.compress.lzochunk.LzoCrc;

private import ocean.core.Exception: CompressException, assertEx;

/******************************************************************************

    Lzo class

 ******************************************************************************/

class Lzo
{
    alias LzoCrc.crc32 crc32;
    
    /**************************************************************************

        Working memory buffer for lzo1x_1_compress()
    
     **************************************************************************/

    private void[] workmem;
    
    /**************************************************************************

        Static constructor
        
        Throws:
            CompressException if the library pouts
        
     **************************************************************************/

    static this ( )
    {
        assertEx!(CompressException)(!lzo_init(), "Lzo kaputt");
    }

    /**************************************************************************

        Constructor
    
     **************************************************************************/

    public this ( )
    {
        this.workmem = new void[Lzo1x1WorkmemSize];
    }
    
    /**************************************************************************

        Compresses src data. dst must have a length of at least
        maxCompressedLength(src.length).
        
        Params:
            src = data to compress
            dst = compressed data destination buffer
        
        Returns:
            length of compressed data in dst

        Throws:
            CompressionException on error
        
     **************************************************************************/

    size_t compress ( void[] src, void[] dst )
    in
    {
        assert (dst.length >= this.maxCompressedLength(src.length), typeof (this).stringof ~ ".compress: dst buffer too short");
    }
    body
    {
        size_t len;
        
        this.checkStatus(lzo1x_1_compress(cast (ubyte*) src.ptr, src.length, cast (ubyte*) dst.ptr, &len, this.workmem.ptr));
        
        return len;
    }
        
    /**************************************************************************

        Uncompresses src data. dst must have at least the length of the
        uncompressed data, which must be memorized at compression time.
        
        Note: dst overflow checking is NOT done!
        
        Params:
            src = data to uncompress
            dst = uncompressed data destination buffer
        
        Returns:
            length of uncompressed data in dst
        
        Throws:
            CompressionException on error
            
     **************************************************************************/

    size_t decompress ( void[] src, void[] dst )
    {
        size_t len;
        
        this.checkStatus(lzo1x_decompress(cast (ubyte*) src.ptr, src.length, cast (ubyte*) dst.ptr, &len));
        
        return len;
    }
    
    /**************************************************************************

        Uncompresses src data, checking for dst not to overflow.
        
        Params:
            src = data to uncompress
            dst = uncompressed data destination buffer
        
        Returns:
            length of uncompressed data in dst
        
        Throws:
            CompressionException on error
        
     **************************************************************************/

    size_t decompressSafe ( void[] src, void[] dst )
    {
        size_t len;
        
        this.checkStatus(lzo1x_decompress_safe(cast (ubyte*) src.ptr, src.length, cast (ubyte*) dst.ptr, &len));
        
        return len;
    }
    
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
        return lzo1x_max_compressed_length(uncompressed_length);
    }
    
    /**************************************************************************
    
        Checks if status indicates an error.
        
        Params:
            status = LZO library function return status
            
        Throws:
            resulting 32-bit CRC value
    
     **************************************************************************/

    static void checkStatus ( LzoStatus status )
    {
        switch (status)
        {
            case LzoStatus.Error:
                throw new CompressException(typeof (this).stringof ~ ": Error");
                
            case LzoStatus.OutOfMemory:
                throw new CompressException(typeof (this).stringof ~ ": Out Of Memory");
                
            case LzoStatus.NotCompressible:
                throw new CompressException(typeof (this).stringof ~ ": Not Compressible");
                
            case LzoStatus.InputOverrun:
                throw new CompressException(typeof (this).stringof ~ ": Input Overrun");
                
            case LzoStatus.OutputOverrun:
                throw new CompressException(typeof (this).stringof ~ ": Output Overrun");
                
            case LzoStatus.LookBehindOverrun:
                throw new CompressException(typeof (this).stringof ~ ": Look Behind Overrun");
                
            case LzoStatus.EofNotFound:
                throw new CompressException(typeof (this).stringof ~ ": Eof Not Found");
                
            case LzoStatus.InputNotConsumed:
                throw new CompressException(typeof (this).stringof ~ ": Input Not Consumed");
                
            case LzoStatus.NotYetImplemented:
                throw new CompressException(typeof (this).stringof ~ ": Not Yet Implemented");
                
            default:
                return;
        }
    }
    
    /**************************************************************************
    
        Destructor
    
     **************************************************************************/

   ~this ( )
    {
        delete this.workmem;
    }
}

/******************************************************************************

    Unit test
    
    Note: The unit test requires a file named "lzotest.dat" in the current
    working directory at runtime. This file provides the data to be compressed
    for testing and performance measurement.

 ******************************************************************************/

debug (LzoUnitTest):

import tango.util.log.Trace;
import tango.io.device.File;
import tango.time.StopWatch;

import ocean.text.util.MetricPrefix;

/******************************************************************************

    Rounds x to the nearest integer value
    
    Params:
        x = value to round
        
    Returns:
        nearest integer value of x
    
 ******************************************************************************/

extern (C) int lrintf ( float x );

unittest
{
    StopWatch swatch;
    
    MetricPrefix pre_comp_sz, pre_uncomp_sz,
                 pre_comp_tm, pre_uncomp_tm, pre_crc_tm;
    
    Trace.formatln("LZO unittest: loading lzotest.dat");
    
    scope file = new File("lzotest.dat");
    
    scope data         = new void[file.length];
    scope uncompressed = new void[file.length];
    
    file.read(data);
    
    file.close();
    
    Trace.formatln("LZO unittest: loaded {} bytes from lzotest.dat, compressing...", uncompressed.length);
    
    scope lzo        = new Lzo;
    scope compressed = new void[lzo.maxCompressedLength(uncompressed.length)];
    
    swatch.start();
    
    compressed.length = lzo.compress(data, compressed);
    
    ulong compr_us = swatch.microsec;
    
    size_t uncompr_len = lzo.decompress(compressed, uncompressed);
    
    ulong uncomp_us = swatch.microsec;
    
    uint crc32_data = lzo.crc32(data);
    
    ulong crc_us = swatch.microsec;
    
    assert (uncompr_len == data.length,            "uncompressed data length mismatch");
    assert (uncompressed == data,                  "uncompressed data mismatch");
    assert (lzo.crc32(uncompressed) == crc32_data, "uncompressed data CRC-32 mismatch");
    
    crc_us    -= uncomp_us;
    uncomp_us -= compr_us;
    
    pre_comp_sz.bin(compressed.length);
    pre_uncomp_sz.bin(uncompressed.length);
    
    pre_comp_tm.dec(compr_us, -2);
    pre_uncomp_tm.dec(uncomp_us, -2);
    pre_crc_tm.dec(crc_us, -2);
    
    Trace.formatln("LZO unittest results:\n\t"
                   "uncompressed length: {} {}B\t({} bytes)\n\t"
                   "compressed length:   {} {}B\t({} bytes)\n\t"
                   "compression ratio:   {}%\n\t"
                   "compression time:    {} {}s\t({} µs)\n\t"
                   "uncompression time:  {} {}s\t({} µs)\n\t"
                   "CRC-32 time:         {} {}s\t({} µs)\n\t"
                   "CRC-32 (uncompr'd):  0x{:X8}\n",
                   pre_uncomp_sz.scaled, pre_uncomp_sz.prefix, uncompressed.length,
                   pre_comp_sz.scaled, pre_comp_sz.prefix, compressed.length,
                   lrintf((compressed.length * 100.f) / uncompressed.length),
                   pre_comp_tm.scaled, pre_comp_tm.prefix, compr_us,
                   pre_uncomp_tm.scaled, pre_uncomp_tm.prefix, uncomp_us,
                   pre_crc_tm.scaled, pre_crc_tm.prefix, crc_us,
                   crc32_data);
}
