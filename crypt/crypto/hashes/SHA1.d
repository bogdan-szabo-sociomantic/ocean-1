/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.SHA1;

public import ocean.crypt.crypto.Hash;

/** 
 * Implementation of the US NSA's SHA-1.
 * 
 * Conforms: FIPS 180-1
 * References: http://www.itl.nist.gov/fipspubs/fip180-1.htm
 * Bugs: SHA-1 is not cryptographically secure.
 */
class SHA1 : Hash
{
    protected uint h0, h1, h2, h3, h4;
    
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
        return 20;
    }
    
    char[] name()
    {
        return "SHA1";
    }
    
    void transform(ubyte[] input)
    {
        uint[] w = new uint[80];
        
        for (int i = 0, j = 0; i < 16; i++,j+=int.sizeof)
            w[i] = ByteConverter.BigEndian.to!(uint)(input[j..j+int.sizeof]);
        
        for (int i = 16; i < 80; i++)
            w[i] = Bitwise.rotateLeft(w[i-3]^w[i-8]^w[i-14]^w[i-16], 1);
        
        uint a = h0,
             b = h1,
             c = h2,
             d = h3,
             e = h4;

        int i = 0;
        for (; i < 20;)
        {
            e += Bitwise.rotateLeft(a, 5) + f0(b, c, d) + w[i++];
            b = Bitwise.rotateLeft(b, 30);
            
            d += Bitwise.rotateLeft(e, 5) + f0(a, b, c) + w[i++];
            a = Bitwise.rotateLeft(a, 30);
       
            c += Bitwise.rotateLeft(d, 5) + f0(e, a, b) + w[i++];
            e = Bitwise.rotateLeft(e, 30);
       
            b += Bitwise.rotateLeft(c, 5) + f0(d, e, a) + w[i++];
            d = Bitwise.rotateLeft(d, 30);

            a += Bitwise.rotateLeft(b, 5) + f0(c, d, e) + w[i++];
            c = Bitwise.rotateLeft(c, 30);
        }
        
        for (; i < 40;)
        {
            e += Bitwise.rotateLeft(a, 5) + f1(b, c, d) + w[i++];
            b = Bitwise.rotateLeft(b, 30);
            
            d += Bitwise.rotateLeft(e, 5) + f1(a, b, c) + w[i++];
            a = Bitwise.rotateLeft(a, 30);
       
            c += Bitwise.rotateLeft(d, 5) + f1(e, a, b) + w[i++];
            e = Bitwise.rotateLeft(e, 30);
       
            b += Bitwise.rotateLeft(c, 5) + f1(d, e, a) + w[i++];
            d = Bitwise.rotateLeft(d, 30);

            a += Bitwise.rotateLeft(b, 5) + f1(c, d, e) + w[i++];
            c = Bitwise.rotateLeft(c, 30);
        }
        
        for (; i < 60;)
        {
            e += Bitwise.rotateLeft(a, 5) + f2(b, c, d) + w[i++];
            b = Bitwise.rotateLeft(b, 30);
            
            d += Bitwise.rotateLeft(e, 5) + f2(a, b, c) + w[i++];
            a = Bitwise.rotateLeft(a, 30);
       
            c += Bitwise.rotateLeft(d, 5) + f2(e, a, b) + w[i++];
            e = Bitwise.rotateLeft(e, 30);
       
            b += Bitwise.rotateLeft(c, 5) + f2(d, e, a) + w[i++];
            d = Bitwise.rotateLeft(d, 30);

            a += Bitwise.rotateLeft(b, 5) + f2(c, d, e) + w[i++];
            c = Bitwise.rotateLeft(c, 30);
        }
        
        for (; i < 80;)
        {
            e += Bitwise.rotateLeft(a, 5) + f3(b, c, d) + w[i++];
            b = Bitwise.rotateLeft(b, 30);
            
            d += Bitwise.rotateLeft(e, 5) + f3(a, b, c) + w[i++];
            a = Bitwise.rotateLeft(a, 30);
       
            c += Bitwise.rotateLeft(d, 5) + f3(e, a, b) + w[i++];
            e = Bitwise.rotateLeft(e, 30);
       
            b += Bitwise.rotateLeft(c, 5) + f3(d, e, a) + w[i++];
            d = Bitwise.rotateLeft(d, 30);

            a += Bitwise.rotateLeft(b, 5) + f3(c, d, e) + w[i++];
            c = Bitwise.rotateLeft(c, 30);
        }

        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
        h4 += e;
    }
    
    private uint f0(uint x, uint y, uint z)
    {
        return (z^(x&(y^z))) + 0x5a827999;
    }

    private uint f1(uint x, uint y, uint z)
    {
        return (x^y^z) + 0x6ed9eba1;
    }

    private uint f2(uint x, uint y, uint z)
    {
        return ((x&y)|(z&(x|y))) + 0x8f1bbcdc;
    }

    private uint f3(uint x, uint y, uint z)
    {
        return (x^y^z) + 0xca62c1d6;
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
        
        reset();
        return result;
    }

    void reset()
    {
        super.reset();
        h0 = 0x67452301u;
        h1 = 0xefcdab89u;
        h2 = 0x98badcfeu;
        h3 = 0x10325476u;
        h4 = 0xc3d2e1f0u;
    }
    
    SHA1 copy()
    {
        SHA1 h = new SHA1(buffer[0..index]);
        h.bytes = bytes;
        h.h0 = h0;
        h.h1 = h1;
        h.h2 = h2;
        h.h3 = h3;
        h.h4 = h4;
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
                "a",
                "0123456701234567012345670123456701234567012345670123456701234567"
            ];
            
            static int[] test_repeat = [
                1, 1, 1, 1000000, 10
            ];
            
            static char[][] test_results = [
                "da39a3ee5e6b4b0d3255bfef95601890afd80709",
                "a9993e364706816aba3e25717850c26c9cd0d89d",
                "84983e441c3bd26ebaae4aa1f95129e5e54670f1",
                "34aa973cd4c4daa4f61eeb2bdbad27316534016f",
                "dea356a2cddd90c7a7ecedc5ebb563934f460452"
            ];
            
            SHA1 h = new SHA1();
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
