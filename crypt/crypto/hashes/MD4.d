/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2009. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.MD4;

public import ocean.crypt.crypto.Hash;

/** 
 * Implementation of Ron Rivest's MD4.
 * 
 * Conforms: RFC 1320
 * References: http://www.faqs.org/rfcs/rfc1320.html
 * Bugs: MD4 is not cryptographically secure.
 */
class MD4 : Hash
{
    private uint h0, h1, h2, h3;
    
    // Shift amounts
    private enum
    {
        S11 =  3,
        S12 =  7,
        S13 = 11,
        S14 = 19,
        
        S21 =  3,
        S22 =  5,
        S23 =  9,
        S24 = 13,
        
        S31 =  3,
        S32 =  9,
        S33 = 11,
        S34 = 15
    };
    
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
        return 16;
    }
    
    char[] name()
    {
        return "MD4";
    }
    
    void transform(ubyte[] input)
    {
        uint[] w = new uint[16];
        
        for (int i = 0, j = 0; i < 16; i++,j+=int.sizeof)
            w[i] = ByteConverter.LittleEndian.to!(uint)(input[j..j+int.sizeof]);
        
        uint a = h0,
             b = h1,
             c = h2,
             d = h3;
        
        // Round 1
        ff(a, b, c, d, w[ 0], S11);
        ff(d, a, b, c, w[ 1], S12);
        ff(c, d, a, b, w[ 2], S13);
        ff(b, c, d, a, w[ 3], S14);
        ff(a, b, c, d, w[ 4], S11);
        ff(d, a, b, c, w[ 5], S12);
        ff(c, d, a, b, w[ 6], S13);
        ff(b, c, d, a, w[ 7], S14);
        ff(a, b, c, d, w[ 8], S11);
        ff(d, a, b, c, w[ 9], S12);
        ff(c, d, a, b, w[10], S13);
        ff(b, c, d, a, w[11], S14);
        ff(a, b, c, d, w[12], S11);
        ff(d, a, b, c, w[13], S12);
        ff(c, d, a, b, w[14], S13);
        ff(b, c, d, a, w[15], S14);
        
        // Round 2
        gg(a, b, c, d, w[ 0], S21);
        gg(d, a, b, c, w[ 4], S22);
        gg(c, d, a, b, w[ 8], S23);
        gg(b, c, d, a, w[12], S24);
        gg(a, b, c, d, w[ 1], S21);
        gg(d, a, b, c, w[ 5], S22);
        gg(c, d, a, b, w[ 9], S23);
        gg(b, c, d, a, w[13], S24);
        gg(a, b, c, d, w[ 2], S21);
        gg(d, a, b, c, w[ 6], S22);
        gg(c, d, a, b, w[10], S23);
        gg(b, c, d, a, w[14], S24);
        gg(a, b, c, d, w[ 3], S21);
        gg(d, a, b, c, w[ 7], S22);
        gg(c, d, a, b, w[11], S23);
        gg(b, c, d, a, w[15], S24);
        
        // Round 3
        hh(a, b, c, d, w[ 0], S31);
        hh(d, a, b, c, w[ 8], S32);
        hh(c, d, a, b, w[ 4], S33);
        hh(b, c, d, a, w[12], S34);
        hh(a, b, c, d, w[ 2], S31);
        hh(d, a, b, c, w[10], S32);
        hh(c, d, a, b, w[ 6], S33);
        hh(b, c, d, a, w[14], S34);
        hh(a, b, c, d, w[ 1], S31);
        hh(d, a, b, c, w[ 9], S32);
        hh(c, d, a, b, w[ 5], S33);
        hh(b, c, d, a, w[13], S34);
        hh(a, b, c, d, w[ 3], S31);
        hh(d, a, b, c, w[11], S32);
        hh(c, d, a, b, w[ 7], S33);
        hh(b, c, d, a, w[15], S34);
          
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
    }
    
    private uint f(uint x, uint y, uint z)
    {
        return (x&y)|(~x&z);
    }

    private uint h(uint x, uint y, uint z)
    {
        return x^y^z;
    }
    
    private uint g(uint x, uint y, uint z)
    {
        return (x&y)|(x&z)|(y&z);
    }

    private void ff(ref uint a, uint b, uint c, uint d, uint x, uint s)
    {
        a += f(b, c, d) + x;
        a = Bitwise.rotateLeft(a, s);
    }

    private void gg(ref uint a, uint b, uint c, uint d, uint x, uint s)
    {
        a += g(b, c, d) + x + 0x5a827999u;
        a = Bitwise.rotateLeft(a, s);
    }

    private void hh(ref uint a, uint b, uint c, uint d, uint x, uint s)
    {
        a += h(b, c, d) + x + 0x6ed9eba1u;
        a = Bitwise.rotateLeft(a, s);
    }

    ubyte[] digest()
    {
        padMessage(MODE_MD);
        ubyte[] result = new ubyte[digestSize];
        
        result[0..4] = ByteConverter.LittleEndian.from!(uint)(h0);
        result[4..8] = ByteConverter.LittleEndian.from!(uint)(h1);
        result[8..12] = ByteConverter.LittleEndian.from!(uint)(h2);
        result[12..16] = ByteConverter.LittleEndian.from!(uint)(h3);
        
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
    }
    
    MD4 copy()
    {
        MD4 h = new MD4(buffer[0..index]);
        h.bytes = bytes;
        h.h0 = h0;
        h.h1 = h1;
        h.h2 = h2;
        h.h3 = h3;
        return h;
    }
    
    debug (UnitTest)
    {
        unittest
        {
            static char[][] test_inputs = [
                "",
                "a",
                "abc",
                "message digest",
                "abcdefghijklmnopqrstuvwxyz",
                "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
                "12345678901234567890123456789012345678901234567890123456789012345678901234567890"
            ];
            
            static char[][] test_results = [
                "31d6cfe0d16ae931b73c59d7e0c089c0",
                "bde52cb31de33e46245e05fbdbd6fb24",
                "a448017aaf21d8525fc10ae87aa6729d",
                "d9130a8164549fe818874806e1c7014b",
                "d79e1c308aa5bbcdeea8ed63df412da9",
                "043f8582f241db351ce627e153e7f0e4",
                "e33b4ddc9c38f2199c3e7b164fcc0536"
            ];
            
            MD4 h = new MD4();
            foreach (uint i, char[] input; test_inputs)
            {
                h.update(input);
                char[] digest = h.hexDigest();
                assert(digest == test_results[i], 
                        h.name~": ("~digest~") != ("~test_results[i]~")");
            }
        }
    }
}
