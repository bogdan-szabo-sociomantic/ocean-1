/*****************************************************************************

    Binding of the LZO library CRC-32 functions
    
    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt
    
    Unfortunately, the definitions of the CRC-32 functions are currently missing
    in the source code of the MiniLZO although they are declared in the MiniLZO
    include headers.
    Thus, CRC-32 needs to be compiled separately and linked in to MiniLZO. This
    is how it's done:
    
        1. Get the MiniLZO and LZO source code
        2. Copy lzo_crc.c from the LZO to the MiniLZO source code directory (to
           where the other .c files are)
        3. Unfortunately, the include headers are named differently in LZO and
           MiniLZO so lzo_crc.c must be adapted: Edit lzo_crc.c and change
                                                                             ---
                #include "lzo_conf.h"
                                                                             ---
           to
    
                                                                             ---
                #include "lzoconf.h"
                                                                             ---
        
        4. Compile (do not link yet) MiniLZO which consists of minilzo.c
        5. Compile (do not link yet) lzo_crc.c
        6. Link the compiled MiniLZO (minilzo.o) and lzo_crc.o to the library
           binary with the type of your choice (static, dynamic, shared ...).
        
    As an alternative, lzo_crc.o can also be used as a stand-alone CRC-32
    calculator library.
        
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

module ocean.io.compress.lzo.c.lzo_crc;

extern (C)
{
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

    Returns the initial 32-bit CRC value to use with lzo_crc32().
    
    Returns:
        initial 32-bit CRC value

******************************************************************************/

uint lzo_crc32_init ( )
{
    return lzo_crc32(0, null, 0);
}
