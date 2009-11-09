/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.SHA256;

public import ocean.crypt.crypto.Hash;

/**
 * Implementation of the US NSA's SHA-256.
 *
 * Conforms: FIPS-180-2
 * References: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
 */
class SHA256 : Hash
{
    private static const uint[] K = [
        0x428a2f98u, 0x71374491u, 0xb5c0fbcfu, 0xe9b5dba5u,
        0x3956c25bu, 0x59f111f1u, 0x923f82a4u, 0xab1c5ed5u,
        0xd807aa98u, 0x12835b01u, 0x243185beu, 0x550c7dc3u,
        0x72be5d74u, 0x80deb1feu, 0x9bdc06a7u, 0xc19bf174u,
        0xe49b69c1u, 0xefbe4786u, 0x0fc19dc6u, 0x240ca1ccu,
        0x2de92c6fu, 0x4a7484aau, 0x5cb0a9dcu, 0x76f988dau,
        0x983e5152u, 0xa831c66du, 0xb00327c8u, 0xbf597fc7u,
        0xc6e00bf3u, 0xd5a79147u, 0x06ca6351u, 0x14292967u,
        0x27b70a85u, 0x2e1b2138u, 0x4d2c6dfcu, 0x53380d13u,
        0x650a7354u, 0x766a0abbu, 0x81c2c92eu, 0x92722c85u,
        0xa2bfe8a1u, 0xa81a664bu, 0xc24b8b70u, 0xc76c51a3u,
        0xd192e819u, 0xd6990624u, 0xf40e3585u, 0x106aa070u,
        0x19a4c116u, 0x1e376c08u, 0x2748774cu, 0x34b0bcb5u,
        0x391c0cb3u, 0x4ed8aa4au, 0x5b9cca4fu, 0x682e6ff3u,
        0x748f82eeu, 0x78a5636fu, 0x84c87814u, 0x8cc70208u,
        0x90befffau, 0xa4506cebu, 0xbef9a3f7u, 0xc67178f2u
    ];
    
    protected uint h0, h1, h2, h3, h4, h5, h6, h7;
    
    this (void[] input_=null)
    {
        reset();
        super(input_);
    }

    uint blockSize()
    {
        return 64;
    }
    
    uint digestSize()
    {
        return 32;
    }
    
    char[] name()
    {
        return "SHA256";
    }
    
    void transform(ubyte[] input)
    {
        uint[] w = new uint[64];
        
        for (int i = 0, j = 0; i < 16; i++,j+=int.sizeof)
            w[i] = ByteConverter.BigEndian.to!(uint)(input[j..j+int.sizeof]);
        
        for (int i = 16; i < 64; i++)
            w[i] = theta1(w[i-2]) + w[i-7] + theta0(w[i-15]) + w[i-16];
        
        uint a = h0,
             b = h1,
             c = h2,
             d = h3,
             e = h4,
             f = h5,
             g = h6,
             h = h7;

        for (int i = 0; i < 64; i++)
        {
            uint t1 = h + sum1(e) + ch(e,f,g) + K[i] + w[i],
                 t2 = sum0(a) + maj(a,b,c);
            h = g;
            g = f;
            f = e;
            e = d + t1;
            d = c;
            c = b;
            b = a;
            a = t1 + t2;
        }
            
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
        h4 += e;
        h5 += f;
        h6 += g;
        h7 += h;
    }
    
    private uint ch(uint x, uint y, uint z)
    {
            return (z ^ (x & (y ^ z)));
    }
    
    private uint maj(uint x, uint y, uint z)
    {
            return ((x & y) | (z & (x ^ y)));
    }

    private uint sum0(uint x)
    {
            return Bitwise.rotateRight(x,2)^Bitwise.rotateRight(x,13)^Bitwise.rotateRight(x,22);
    }

    private uint sum1(uint x)
    {
            return Bitwise.rotateRight(x,6)^Bitwise.rotateRight(x,11)^Bitwise.rotateRight(x,25);
    }

    private uint theta0(uint x)
    {
        return Bitwise.rotateRight(x,7)^Bitwise.rotateRight(x,18)^(x >> 3);
    }

    private uint theta1(uint x)
    {
        return Bitwise.rotateRight(x,17)^Bitwise.rotateRight(x,19)^(x >> 10);
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
        result[28..32] = ByteConverter.BigEndian.from!(uint)(h7);

        reset();
        return result;
    }

    void reset()
    {
        super.reset();
        h0 = 0x6a09e667u;
        h1 = 0xbb67ae85u;
        h2 = 0x3c6ef372u;
        h3 = 0xa54ff53au;
        h4 = 0x510e527fu;
        h5 = 0x9b05688cu;
        h6 = 0x1f83d9abu;
        h7 = 0x5be0cd19u;
    }
    
    SHA256 copy()
    {
        SHA256 h = new SHA256(buffer[0..index]);
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
                "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
                "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
                "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1",
                "cdc76e5c9914fb9281a1c7e284d73e67f1809a48a497200e046d39ccc7112cd0"
            ];
            
            SHA256 h = new SHA256();
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
