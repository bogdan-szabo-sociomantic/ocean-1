/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.SHA384;

import ocean.crypt.crypto.hashes.SHA512;

/** 
 * Implementation of the US NSA's SHA-384.
 * 
 * Conforms: FIPS-180-2
 * References: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
 */
class SHA384 : SHA512
{
    this (void[] input_=null)
    {
        reset();
        super(input_);
    }
    
    uint digestSize()
    {
        return 48;
    }
    
    char[] name()
    {
        return "SHA384";
    }

    ubyte[] digest()
    {
        padMessage(MODE_SHA);
        ubyte[] result = new ubyte[digestSize];
        
        result[0..8] = ByteConverter.BigEndian.from!(ulong)(h0);
        result[8..16] = ByteConverter.BigEndian.from!(ulong)(h1);
        result[16..24] = ByteConverter.BigEndian.from!(ulong)(h2);
        result[24..32] = ByteConverter.BigEndian.from!(ulong)(h3);
        result[32..40] = ByteConverter.BigEndian.from!(ulong)(h4);
        result[40..48] = ByteConverter.BigEndian.from!(ulong)(h5);

        reset();
        return result;
    }

    void reset()
    {
        super.reset();
        h0 = 0xcbbb9d5dc1059ed8u,
        h1 = 0x629a292a367cd507u,
        h2 = 0x9159015a3070dd17u,
        h3 = 0x152fecd8f70e5939u,
        h4 = 0x67332667ffc00b31u,
        h5 = 0x8eb44a8768581511u,
        h6 = 0xdb0c2e0d64f98fa7u,
        h7 = 0x47b5481dbefa4fa4u;
    }
    
    SHA384 copy()
    {
        SHA384 h = new SHA384(buffer[0..index]);
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
                "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"~
                "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
                "a"
            ];
            
            static int[] test_repeat = [
                1, 1, 1, 1000000
            ];
            
            static char[][] test_results = [
                "38b060a751ac96384cd9327eb1b1e36a21fdb71114be0743"~
                "4c0cc7bf63f6e1da274edebfe76f65fbd51ad2f14898b95b",
                
                "cb00753f45a35e8bb5a03d699ac65007272c32ab0eded163"~
                "1a8b605a43ff5bed8086072ba1e7cc2358baeca134c825a7",
                
                "09330c33f71147e83d192fc782cd1b4753111b173b3b05d2"~
                "2fa08086e3b0f712fcc7c71a557e2db966c3e9fa91746039",
                
                "9d0e1809716474cb086e834e310a4a1ced149e9c00f24852"~
                "7972cec5704c2a5b07b8b3dc38ecc4ebae97ddd87f3d8985"
            ];

            SHA384 h = new SHA384();
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
