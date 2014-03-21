/*******************************************************************************

    LZO1X-1 (Mini LZO) compressor/uncompressor generating/accepting chunks of
    compressed data with a length and checksum header

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

    Usage example:

                                                                             ---
        import $(TITLE);

        void[] lzo_chunk;
        void[] uncompressed_chunk;

        void run ( )
        {
            scope lzo = new LzoChunk;

            // preallocate lzo_chunk and uncompressed_chunk (optional)

            lzo_chunk = new void[LzoChunk.maxChunkLength(0x1000)];

            uncompressed_chunk  = new void[0x1000];

            char[] data;

            // populate data with data to compress...

            lzo.compress(data, lzo_chunk);

            // lzo_chunk now holds an LZO chunk with compressed data

            lzo.uncompress(lzo_chunk, uncompressed);

            // uncompressed_chunk now holds data, restored from lzo_chunk
        }
                                                                             ---

 ******************************************************************************/

module ocean.io.compress.lzo.LzoChunk;

/*******************************************************************************

    Imports

 ******************************************************************************/

private     import      ocean.io.compress.Lzo;

private     import      ocean.io.compress.lzo.LzoHeader;

private     import      ocean.io.compress.CompressException;

private     import      ocean.core.Exception: assertEx;

private     import      ocean.util.log.Trace;

/*******************************************************************************

    LzoChunk compressor/decompressor

    Chunk data layout if size_t has a width of 32-bit:

                                                                             ---
        void[] chunk

        chunk[0 .. 16] // header
        chunk[16 .. $] // compressed data
                                                                             ---

    Header data layout

                                                                             ---
        chunk[0  ..  4] // length of chunk[4 .. $] (or compressed data length
                        // + header length - 4)
        chunk[4 ..   8] // 32-bit CRC value of following header elements and
                        // compressed data (chunk[8 .. $]), calculated using
                        //  lzo_crc32()
        chunk[8  .. 12] // chunk/compression type code (signed 32-bit integer)
        chunk[12 .. 16] // length of uncompressed data
                                                                             ---

 ******************************************************************************/

class LzoChunk ( bool LengthInline = true )
{
    /***************************************************************************

        Lzo instance

     **************************************************************************/

    private             Lzo                     lzo;

    /***************************************************************************

        Flag set to true if the lzo instance is a reference (ie was passed from
        the outside, is *not* owned by this instance, and should not be deleted
        in the destructor).

     **************************************************************************/

    bool lzo_is_reference;

    /***************************************************************************

        Constructor - creates a new lzo instance internally.

     **************************************************************************/

    public this ( )
    {
        this.lzo   = new Lzo;
    }

    /***************************************************************************

        Constructor - sets this instance to use an lzo object passed externally
        (this allows multiple instances to use the same lzo object).

        Params:
            lzo = lzo object to use

     **************************************************************************/

    public this ( Lzo lzo )
    {
        this.lzo = lzo;
        this.lzo_is_reference = true;
    }

    /***************************************************************************

        Destructor - deletes the internal lzo object if it was created by this
        class

     **************************************************************************/

    void dispose ( )
    {
        if ( !this.lzo_is_reference )
        {
            delete this.lzo;
        }
    }

    /***************************************************************************

        Compresses a data chunk

        Params:
            data = data to compress
            compressed = LZO compressed data chunk with header
                         (output ref parameter)

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) compress ( T ) ( void[] data, ref T[] compressed )
    {
        static assert (T.sizeof == 1);

        LzoHeader!(LengthInline) header;

        size_t end;

        header.uncompressed_length = data.length;
        header.type                = header.type.LZO1X;

        compressed.length = this.maxChunkLength(data.length);

        end = header.length + this.lzo.compress(data, header.strip(compressed));

        compressed.length = end;

        header.write(compressed);

        return this;
    }

    /***************************************************************************

        Uncompresses a LZO chunk

        Params:
            compressed = LZO compressed data chunk to uncompress
            data = uncompressed data (output ref parameter)

        Returns:
            this instance

        FIXME: - Add assertion for chunk length

     **************************************************************************/

    public typeof (this) uncompress ( T ) ( void[] compressed, ref T[] data )
    {
        static assert (T.sizeof == 1);

        LzoHeader!(LengthInline) header;

        void[] buf = header.read(compressed);

        data.length = header.uncompressed_length;

        assertEx!(CompressException)(header.type == header.type.LZO1X, "Not LZO1X");

        this.lzo.uncompress(buf, data);

        return this;
    }

    /***************************************************************************

        Static method alias, to be used as

                                                                             ---
        static size_t maxCompressedLength ( size_t uncompressed_length );
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

    /***************************************************************************

        Calculates the maximum chunk length from input data which has a length
        of uncompressed_length.

        Note: Surprisingly, this is more than uncompressed_length but that's the
              worst case for completely uncompressable data.

        Parameters:
            uncompressed_length = length of data to compressed

        Returns:
            maximum compressed length of data

     **************************************************************************/

    static size_t maxChunkLength ( size_t uncompressed_length )
    {
        return maxCompressedLength(uncompressed_length) + LzoHeader!().length;
    }
}

debug (OceanUnitTest) private:

/*******************************************************************************

    Unit test

    Add -debug=GcDisabled to the compiler command line to disable the garbage
    collector.

    Note: The unit test requires a file named "lzotest.dat" in the current
    working directory at runtime. This file provides the data to be compressed
    for testing and performance measurement.

 ******************************************************************************/

import tango.io.device.File;
import tango.time.StopWatch;

debug (GcDisabled) import tango.core.internal.gcInterface: gc_disable;

import ocean.text.util.MetricPrefix;

import tango.stdc.signal: signal, SIGINT;

/*******************************************************************************

    Rounds x to the nearest integer value

    Params:
        x = value to round

    Returns:
        nearest integer value of x

 ******************************************************************************/

extern (C) int lrintf ( float x );

/*******************************************************************************

    Terminator structure

 ******************************************************************************/

struct Terminator
{
    static:

    /***************************************************************************

        Termination flag

     **************************************************************************/

    bool terminated = false;

    /***************************************************************************

        Signal handler; raises the termination flag

     **************************************************************************/

    extern (C) void terminate ( int code )
    {
        this.terminated = true;
    }
}

unittest
{
    // Uncomment the next line to see UnitTest output
    // debug = Verbose;

    debug (GcDisabled)
    {
        pragma (msg, "LzoChunk unittest: garbage collector disabled");
        gc_disable();
    }

    StopWatch swatch;

    MetricPrefix pre_comp_sz, pre_uncomp_sz,
                 pre_comp_tm, pre_uncomp_tm, pre_crc_tm;

    debug (Verbose) Trace.formatln("LzoChunk unittest: loading test data from file \"lzotest.dat\"");

    File file;

    try file = new File("lzotest.dat");
    catch (Exception e)
    return;

    scope data         = new void[file.length];
    scope compressed   = new void[LzoChunk!().maxChunkLength(data.length)];
    scope uncompressed = new void[file.length];

    scope lzo          = new LzoChunk!();

    file.read(data);

    file.close();

    Trace.formatln("LzoChunk unittest: loaded {} bytes of test data, compressing...", data.length);

    swatch.start();

    lzo.compress(data, compressed);

    ulong compr_us = swatch.microsec;

    lzo.uncompress(compressed, uncompressed);

    ulong uncomp_us = swatch.microsec;

    uncomp_us -= compr_us;

    assert (data.length == uncompressed.length, "data lengthmismatch");
    assert (data        == uncompressed,        "data mismatch");

    pre_comp_sz.bin(compressed.length);
    pre_uncomp_sz.bin(data.length);

    pre_comp_tm.dec(compr_us, -2);
    pre_uncomp_tm.dec(uncomp_us, -2);

    Trace.formatln("LzoChunk unittest results:\n\t"
                   "uncompressed length: {} {}B\t({} bytes)\n\t"
                   "compressed length:   {} {}B\t({} bytes)\n\t"
                   "compression ratio:   {}%\n\t"
                   "compression time:    {} {}s\t({} µs)\n\t"
                   "uncompression time:  {} {}s\t({} µs)\n\t"
                   "\n"
                   "LzoChunk unittest: Looping for memory leak detection; "
                   "watch memory usage and press Ctrl+C to quit",
                   pre_uncomp_sz.scaled, pre_uncomp_sz.prefix, data.length,
                   pre_comp_sz.scaled, pre_comp_sz.prefix, compressed.length,
                   lrintf((compressed.length * 100.f) / data.length),
                   pre_comp_tm.scaled, pre_comp_tm.prefix, compr_us,
                   pre_uncomp_tm.scaled, pre_uncomp_tm.prefix, uncomp_us
                   );

    auto prev_sigint_handler = signal(SIGINT, &Terminator.terminate);

    scope (exit) signal(SIGINT, prev_sigint_handler);

    while (!Terminator.terminated)
    {
        lzo.compress(data, compressed).uncompress(compressed, uncompressed);
    }

    Trace.formatln("\n\nLzoChunk unittest finished\n");
}