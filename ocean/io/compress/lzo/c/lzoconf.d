/*****************************************************************************

    LZO library binding (general utility functions)

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
    ========
    LZO is a portable lossless data compression library written in ANSI C.
    It offers pretty fast compression and very fast decompression.
    Decompression requires no memory.

    The LZO algorithms and implementations are copyrighted OpenSource
    distributed under the GNU General Public License.


 ******************************************************************************/

module ocean.io.compress.lzo.c.lzoconf;


/**************************************************************************

    Force linking to libzlo2 when using this module.

**************************************************************************/

pragma (lib, "lzo2");


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

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len, void* wrkmem ) lzo_compress_t;

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len, void* wrkmem ) lzo_decompress_t;

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len, void* wrkmem ) lzo_optimize_t;

    alias int function ( ubyte* src, size_t src_len,
                         ubyte* dst, size_t* dst_len,
                         void* wrkmem, char* dict, size_t dict_len ) lzo_compress_dict_t;

    alias void* function ( lzo_callback_t* self, size_t items, size_t size ) lzo_alloc_func_t;

    alias void function ( lzo_callback_t* self, void* ptr ) lzo_free_func_t;

    alias void function ( lzo_callback_t*, size_t, size_t, int ) lzo_progress_func_t;

    /**************************************************************************

        lzo_callback_t structure

     **************************************************************************/

    struct lzo_callback_t
    {
        lzo_alloc_func_t    nalloc;
        lzo_free_func_t     nfree;
        lzo_progress_func_t nprogress;

        void* user1;
        size_t  user2;
        size_t user3;
    };

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

    /**************************************************************************

        Calculates a 32-bit CRC value from data in _buf.

        Params:
            _c   = initial 32-bit CRC value
            _buf = data buffer
            _len   = data length

        Returns:
            resulting 32-bit CRC value

    **************************************************************************/

    uint lzo_crc32   ( uint _c, ubyte* _buf, uint _len );

    /**************************************************************************

        Returns the table of 32-bit CRC values of all byte values. The table has
        a length of 0x100.

        Returns:
            table of 32-bit CRC values of all byte values

    **************************************************************************/

    uint* lzo_get_crc32_table ( );
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
                         short.sizeof, int.sizeof, size_t.sizeof, uint.sizeof,size_t.sizeof,
                         (ubyte*).sizeof, (char*).sizeof, (void*).sizeof, lzo_callback_t.sizeof);
}

/******************************************************************************

    Returns the initial 32-bit CRC value to use with lzo_crc32().

    Returns:
        initial 32-bit CRC value

******************************************************************************/

uint lzo_crc32_init ( )
{
    return lzo_crc32(0, null, 0);
}

