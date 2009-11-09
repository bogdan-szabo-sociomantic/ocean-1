/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.misc.checksums.Adler32;

import ocean.crypt.misc.Checksum;

/**
 * Implementation of Mark Adler's Adler32 checksum.
 * 
 * Conforms: RFC 1950
 * References: http://tools.ietf.org/html/rfc1950#page-10
 */
class Adler32 : Checksum
{
    private static const uint BASE = 65521;
    
    uint compute(void[] input_, uint start=1)
    {
        ubyte[] input = cast(ubyte[])input_;
        uint adler = start,
             s1 = adler & 0xffff,
             s2 = (adler >> 16) & 0xffff;
        
        foreach (ubyte i; input)
        {
            s1 = (s1 + i) % BASE;
            s2 = (s2 + s1) % BASE;
        }
        
        return (s2 << 16) + s1;
    }
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        uint compute(char[] input)
        {
            return compute(cast(ubyte[])input);
        }
    }
    
    char[] name()
    {
        return "Adler32";
    }
    
    debug (UnitTest)
    {
        unittest
        {
            static char[][] test_inputs = [
                "",
                "a",
                "checksum",
                "chexksum"
            ];
            
            static const uint[] test_results = [
                0x1u,
                0x620062u,
                0xea10354u,
                0xf0a0369u
            ];
            
            Adler32 adler32 = new Adler32;
            foreach (uint i, char[] j; test_inputs)
                assert(adler32.compute(j) == test_results[i], adler32.name);
        }
    }
}
