/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.SHA224;

import ocean.crypt.crypto.hashes.SHA256;

/**
 * Implementation of the US NSA's SHA-224.
 * 
 * Conforms: FIPS-180-2
 * References: http://csrc.nist.gov/publications/fips/fips180-2/FIPS180-2_changenotice.pdf
 */
class SHA224 : SHA256
{
    this (void[] input_=null)
    {
        reset();
        super(input_);
    }
    
    uint digestSize()
    {
        return 28;
    }
    
    char[] name()
    {
        return "SHA224";
    }
    
    ubyte[] digest()
    {
        padMessage(MODE_SHA);

        ubyte[] result = new ubyte[digestSize];
        
        result[0..4] = ByteConverter.BigEndian.from!(uint)(h0);
        result[4..8] = ByteConverter.BigEndian.from!(uint)(h1);
        result[8..12] = ByteConverter.BigEndian.from!(uint)(h2);
        result[12..16] = ByteConverter.BigEndian.from!(uint)(h3);
        result[16..20] = ByteConverter.BigEndian.from!(uint)(h4);
        result[20..24] = ByteConverter.BigEndian.from!(uint)(h5);
        result[24..28] = ByteConverter.BigEndian.from!(uint)(h6);
        
        reset();
        return result;
    }

    void reset()
    {
        super.reset();
        h0 = 0xc1059ed8u;
        h1 = 0x367cd507u;
        h2 = 0x3070dd17u;
        h3 = 0xf70e5939u;
        h4 = 0xffc00b31u;
        h5 = 0x68581511u;
        h6 = 0x64f98fa7u;
        h7 = 0xbefa4fa4u;
    }
    
    SHA224 copy()
    {
        SHA224 h = new SHA224(buffer[0..index]);
        h.bytes = bytes;
        h.h0 = h0;
        h.h1 = h1;
        h.h2 = h2;
        h.h3 = h3;
        h.h4 = h4;
        h.h5 = h5;
        h.h6 = h6;
        h.h7 = h7;
        return h;
    }
    
    debug (UnitTest)
    {
        unittest
        {
            static char[][] test_inputs = [
                "",
                "abc",
                "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                "a"
            ];
            
            static int[] test_repeat = [
                1, 1, 1, 1000000
            ];
            
            static char[][] test_results = [
                "d14a028c2a3a2bc9476102bb288234c415a2b01f828ea62ac5b3e42f",
                "23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da7",
                "75388b16512776cc5dba5da1fd890150b0c6455cb4f58b1952522525",
                "20794655980c91d8bbb4c1ea97618a4bf03f42581948b2ee4ee7ad67"
            ];
            
            SHA224 h = new SHA224();
            foreach (uint i, char[] input; test_inputs)
            {
                for (int j = 0; j < test_repeat[i]; j++)
                    h.update(input);
                char[] digest = h.hexDigest();
                assert(digest == test_results[i], 
                        h.name~": ("~digest~") != ("~test_results[i]~")");
            }
        }
    }
}
