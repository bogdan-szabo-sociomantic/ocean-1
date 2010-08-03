/*****************************************************************************

    MiniLZO library binding
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt
    
    The MiniLZO library is a lightweight version of the LZO libraray which
    implements only the LZO1X-1 algorithm.
    
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    
    ============================================================================
    LZO -- a real-time data compression library
    ============================================================================
    
    Author  : Markus Franz Xaver Johannes Oberhumer
              <markus@oberhumer.com>
              http://www.oberhumer.com/opensource/lzo/
    Version : 2.03
    Date    : 30 Apr 2008
    
    
    Copyright (C) 2008 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2007 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2006 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2005 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2004 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2003 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2002 Markus Franz Xaver Johannes Oberhumer 
    Copyright (C) 2001 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 2000 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 1999 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 1998 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 1997 Markus Franz Xaver Johannes Oberhumer
    Copyright (C) 1996 Markus Franz Xaver Johannes Oberhumer 
    All Rights Reserved.

    The LZO library is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of
    the License, or (at your option) any later version.

    The LZO library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with the LZO library; see the file COPYING.
    If not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

    Abstract
    --------
    LZO is a portable lossless data compression library written in ANSI C.
    It offers pretty fast compression and very fast decompression.
    Decompression requires no memory.
    
    The LZO algorithms and implementations are copyrighted OpenSource
    distributed under the GNU General Public License.
    
    
 ******************************************************************************/

module ocean.io.compress.minilzo.c.minilzo;

extern (C)
{
    /**************************************************************************
    
        Status codes
    
     **************************************************************************/
    
    enum LzoStatus : int
    {
        OK                =  0, // LZO_E_OK
        Error             = -1, // LZO_E_ERROR
        OutOfMemory       = -2, // LZO_E_OUT_OF_MEMORY      [not used right now]
        NotCompressible   = -3, // LZO_E_NOT_COMPRESSIBLE   [not used right now]
        InputOverrun      = -4, // LZO_E_INPUT_OVERRUN
        OutputOverrun     = -5, // LZO_E_OUTPUT_OVERRUN
        LookBehindOverrun = -6, // LZO_E_LOOKBEHIND_OVERRUN
        EofNotFound       = -7, // LZO_E_EOF_NOT_FOUND
        InputNotConsumed  = -8, // LZO_E_INPUT_NOT_CONSUMED
        NotYetImplemented = -9 // LZO_E_NOT_YET_IMPLEMENTED [not used right now]
    }
    
    /**************************************************************************
    
        Working memory size
    
     **************************************************************************/

    const size_t Lzo1x1WorkmemSize = 0x4000 * (ubyte*).sizeof; 
    
    /**************************************************************************
    
        Function type definitions
    
     **************************************************************************/

    alias int function ( ubyte* src, uint src_len,
                         ubyte* dst, uint* dst_len, void* wrkmem ) lzo_compress_t;
    
    alias int function ( ubyte* src, uint src_len,
                         ubyte* dst, uint* dst_len, void* wrkmem ) lzo_decompress_t;
    
    alias int function ( ubyte* src, uint src_len,
                         ubyte* dst, uint* dst_len, void* wrkmem ) lzo_optimize_t;
    
    alias int function ( ubyte* src, uint src_len,
                         ubyte* dst, uint* dst_len,
                         void* wrkmem, char* dict, uint dict_len ) lzo_compress_dict_t;
    
    alias void* function ( lzo_callback_t* self, uint items, uint size ) lzo_alloc_func_t;
    
    alias void function ( lzo_callback_t* self, void* ptr ) lzo_free_func_t;
    
    alias void function ( lzo_callback_t*, uint, uint, int ) lzo_progress_func_t;
    
    /**************************************************************************
    
        lzo_callback_t structure
    
     **************************************************************************/

    struct lzo_callback_t
    {
        lzo_alloc_func_t    nalloc;
        lzo_free_func_t     nfree;
        lzo_progress_func_t nprogress;
    
        void* user1;
        uint  user2;
        uint  user3;
    };
    
    
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
    
    LzoStatus lzo1x_1_compress ( ubyte* src, uint  src_len,
                                 ubyte* dst, uint* dst_len,
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

    LzoStatus lzo1x_decompress ( ubyte* src, uint src_len,
                           ubyte* dst, uint* dst_len,
                           void* wrkmem = null /* NOT USED */ );
    
    LzoStatus lzo1x_decompress_safe ( ubyte* src, uint src_len,
                                ubyte* dst, uint* dst_len,
                                void* wrkmem = null /* NOT USED */ );
    
    /**************************************************************************
    
        Calculates an Adler-32 value from data in _buf.
        
        Params:
            _adler = initial Adler-32 value
            _buf   = data buffer
            _len   = data length
            
        Returns:
            resulting Adler-32 value
    
     **************************************************************************/

    uint lzo_adler32 ( uint _adler, ubyte* _buf, uint _len );
    
    /**************************************************************************
    
        Returns the library version number.
        
        Returns:
            library version number
    
     **************************************************************************/
    
    uint lzo_version ( );
    
    /**************************************************************************
    
        Initializes the library and informs it about the size of a variety of
        data types.
        
        Note that both "int" and "long" C datatypes correspond to "int" in D;
        D's "long" corresponds to C99's "long long".
        
        Params:
            ver               = supposed library version number
            sizeof_short      = short.sizeof
            sizeof_int        = int.sizeof
            sizeof_long       = int.sizeof
            sizeof_uint32     = uint.sizeof
            sizeof_uint       = uint.sizeof,
            sizeof_dict_t     = (ubyte*).sizeof
            sizeof_charp      = (char*).sizeof
            sizeof_voidp      = (void*).sizeof
            sizeof_callback_t = lzo_callback_t.sizeof
            
        Returns:
            LzoStatus.OK if the library feels that it is in a healty condition
            or something else if it is not well disposed today.
    
     **************************************************************************/

    private LzoStatus __lzo_init_v2( uint ver,
                                     int  sizeof_short,
                                     int  sizeof_int,
                                     int  sizeof_long,
                                     int  sizeof_uint32,
                                     int  sizeof_uint,
                                     int  sizeof_dict_t,    // ubyte*
                                     int  sizeof_charp,
                                     int  sizeof_voidp,
                                     int  sizeof_callback_t );
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

size_t lzo1x_max_compressed_length ( size_t uncompressed_length )
{
    return uncompressed_length + (uncompressed_length >> 4) + 0x40 + 3;
}

/******************************************************************************

    Returns the initial Adler-32 value to use with lzo_adler32().
    
    Returns:
        initial Adler-32 value 

 ******************************************************************************/

uint lzo_adler32_init ( )
{
    return lzo_adler32(0, null, 0);
}

/**************************************************************************

    Initializes the library and informs it about the size of a variety of
    data types.
    
    Returns:
        LzoStatus.OK if the library feels that it is in a healty condition or
        something else if it is not well disposed today.

 **************************************************************************/

int lzo_init ( )
{
    return __lzo_init_v2(lzo_version(),
                         short.sizeof, int.sizeof, int.sizeof, uint.sizeof, uint.sizeof,
                         (ubyte*).sizeof, (char*).sizeof, (void*).sizeof, lzo_callback_t.sizeof);
}
