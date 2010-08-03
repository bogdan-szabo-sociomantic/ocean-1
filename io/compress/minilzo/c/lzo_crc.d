module io.compress.minilzo.c.lzo_crc;

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
