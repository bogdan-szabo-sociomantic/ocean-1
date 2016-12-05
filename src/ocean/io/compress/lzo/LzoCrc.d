/******************************************************************************

    CRC-32 generator, uses LZO's built-in CRC-32 calculator

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

 ******************************************************************************/

module ocean.io.compress.lzo.LzoCrc;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.io.compress.lzo.c.lzoconf: lzo_crc32, lzo_crc32_init;

import ocean.transition;
import ocean.core.TypeConvert;

/******************************************************************************

    LzoCrc structure; contains only static methods

 ******************************************************************************/

struct LzoCrc
{
    static:

    /**************************************************************************

        Calculates a 32-bit CRC value from data.

        Params:
            crc32_in = initial 32-bit CRC value (for iteration)
            data     = data to calculate 32-bit CRC value of

        Returns:
            resulting 32-bit CRC value

    **************************************************************************/

    uint crc32 ( uint crc32_in, in void[] data )
    {
        return lzo_crc32(crc32_in, cast (Const!(ubyte)*) data.ptr,
            castFrom!(size_t).to!(int)(data.length));
    }

    /**************************************************************************

    Calculates a 32-bit CRC value from data.

    Params:
        data = data to calculate 32-bit CRC value of

    Returns:
        resulting 32-bit CRC value

    **************************************************************************/

    uint crc32 ( in void[] data )
    {
        return crc32(lzo_crc32_init(), data);
    }
}
