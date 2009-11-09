/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.misc.Checksum;

/** Base class for 32-bit checksums */
abstract class Checksum
{
    /**
     * Compute a checksum.
     * 
     * Params:
     *     input_ = Data to be processed.
     *     start = Starting value for the checksum.
     *     
     * Returns: The computed 32 bit checksum.
     */
    uint compute(void[] input_, uint start);
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        uint compute(char[] input_, uint start)
        {
            return compute(cast(ubyte[])input_, start);
        }
    }
    
    /** Returns: The name of the checksum algorithm. */
    char[] name();
}
