/*****************************************************************************

    LZO library binding (lzo1x functions)

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

    LZO library bindings based on MiniLZO bindings (MiniLZO library is
    a lightweight version of the LZO libraray which implements only the LZO1X-1
    algorithm), so some symbols will be missing.

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ============================================================================
    LZO -- a real-time data compression library
    ============================================================================

    Author  : Markus Franz Xaver Johannes Oberhumer
              <markus@oberhumer.com>
              http://www.oberhumer.com/opensource/lzo/
    Version : 2.03
    Date    : 30 Apr 2008

 *****************************************************************************/

module ocean.io.compress.lzo.c.lzo1x;


public import ocean.io.compress.lzo.c.lzoconf;


extern (C)
{

    /**************************************************************************

        All compressors compress the memory block at `src' with the uncompressed
        length `src_len' to the address given by `dst'.
        The length of the compressed blocked will be returned in the variable
        pointed by `dst_len'.

        For non-overlapping compression, wrkmem must be a buffer of
        Lzo1x1WorkmemSize bytes in size.

        The two blocks may overlap under certain conditions (see examples/overlap.c),
        thereby allowing "in-place" compression.

        Algorithm:            LZO1X
        Compression level:    LZO1X-1
        Memory requirements:  Lzo1xMem.L1Compress (64 kB on 32-bit machines)

        This compressor is pretty fast.

        Return value:
            Always returns LzoStatus.OK (this function can never fail).

     **************************************************************************/

    LzoStatus lzo1x_1_compress ( ubyte* src, size_t src_len,
                                 ubyte* dst, size_t * dst_len,
                                 void* wrkmem );

    /**************************************************************************

        All decompressors decompress the memory block at `src' with the compressed
        length `src_len' to the address given by `dst'.
        The length of the decompressed block will be returned in the variable
        pointed by `dst_len' - on error the number of bytes that have
        been decompressed so far will be returned.

        The safe decompressors expect that the number of bytes available in
        the `dst' block is passed via the variable pointed by `dst_len'.

        The two blocks may overlap under certain conditions (see examples/overlap.c),
        thereby allowing "in-place" decompression.


        Description of return values:

          LzoStatus.OK
            Success.

          LzoStatus.InputNotConsumed
            The end of the compressed block has been detected before all
            bytes in the compressed block have been used.
            This may actually not be an error (if `src_len' is too large).

          LzoStatus.InputOverrun
            The decompressor requested more bytes from the compressed
            block than available.
            Your data is corrupted (or `src_len' is too small).

          LzoStatus.OututOverrun
            The decompressor requested to write more bytes to the uncompressed
            block than available.
            Either your data is corrupted, or you should increase the number of
            available bytes passed in the variable pointed by `dst_len'.

          LzoStatus.LookBehindOverrun
            Your data is corrupted.

          LzoStatus.EofNotFound
            No EOF code was found in the compressed block.
            Your data is corrupted (or `src_len' is too small).

          LzoStatus.Error
            Any other error (data corrupted).

     **************************************************************************/

    LzoStatus lzo1x_decompress ( ubyte* src, size_t src_len,
                           ubyte* dst, size_t* dst_len,
                           void* wrkmem = null /* NOT USED */ );

    LzoStatus lzo1x_decompress_safe ( ubyte* src, size_t src_len,
                                ubyte* dst, size_t* dst_len,
                                void* wrkmem = null /* NOT USED */ );

}

