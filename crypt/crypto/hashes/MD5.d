/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.MD5;

public import ocean.crypt.crypto.Hash;

/** 
 * Implementation of Ron Rivest's MD5.
 * 
 * Conforms: RFC 1321
 * References: http://www.faqs.org/rfcs/rfc1321.html
 * Bugs: MD5 is not cryptographically secure.
 */
class MD5 : Hash
{
    private uint h0, h1, h2, h3;
    
    // Shift amounts
    private enum
    {
        S11 =  7,
        S12 = 12,
        S13 = 17,
        S14 = 22,
        
        S21 =  5,
        S22 =  9,
        S23 = 14,
        S24 = 20,
        
        S31 =  4,
        S32 = 11,
        S33 = 16,
        S34 = 23,
        
        S41 =  6,
        S42 = 10,
        S43 = 15,
        S44 = 21
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
        return "MD5";
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
        
        // Round 1 -- FIGHT!
        ff(a, b, c, d, w[ 0], S11, 0xd76aa478u);
        ff(d, a, b, c, w[ 1], S12, 0xe8c7b756u);
        ff(c, d, a, b, w[ 2], S13, 0x242070dbu);
        ff(b, c, d, a, w[ 3], S14, 0xc1bdceeeu);
        ff(a, b, c, d, w[ 4], S11, 0xf57c0fafu);
        ff(d, a, b, c, w[ 5], S12, 0x4787c62au);
        ff(c, d, a, b, w[ 6], S13, 0xa8304613u);
        ff(b, c, d, a, w[ 7], S14, 0xfd469501u);
        ff(a, b, c, d, w[ 8], S11, 0x698098d8u);
        ff(d, a, b, c, w[ 9], S12, 0x8b44f7afu);
        ff(c, d, a, b, w[10], S13, 0xffff5bb1u);
        ff(b, c, d, a, w[11], S14, 0x895cd7beu);
        ff(a, b, c, d, w[12], S11, 0x6b901122u);
        ff(d, a, b, c, w[13], S12, 0xfd987193u);
        ff(c, d, a, b, w[14], S13, 0xa679438eu);
        ff(b, c, d, a, w[15], S14, 0x49b40821u);

        // Round 2
        gg(a, b, c, d, w[ 1], S21, 0xf61e2562u);
        gg(d, a, b, c, w[ 6], S22, 0xc040b340u);
        gg(c, d, a, b, w[11], S23, 0x265e5a51u);
        gg(b, c, d, a, w[ 0], S24, 0xe9b6c7aau);
        gg(a, b, c, d, w[ 5], S21, 0xd62f105du);
        gg(d, a, b, c, w[10], S22, 0x02441453u);
        gg(c, d, a, b, w[15], S23, 0xd8a1e681u);
        gg(b, c, d, a, w[ 4], S24, 0xe7d3fbc8u);
        gg(a, b, c, d, w[ 9], S21, 0x21e1cde6u);
        gg(d, a, b, c, w[14], S22, 0xc33707d6u);
        gg(c, d, a, b, w[ 3], S23, 0xf4d50d87u);
        gg(b, c, d, a, w[ 8], S24, 0x455a14edu);
        gg(a, b, c, d, w[13], S21, 0xa9e3e905u);
        gg(d, a, b, c, w[ 2], S22, 0xfcefa3f8u);
        gg(c, d, a, b, w[ 7], S23, 0x676f02d9u);
        gg(b, c, d, a, w[12], S24, 0x8d2a4c8au);

        // Round 3
        hh(a, b, c, d, w[ 5], S31, 0xfffa3942u);
        hh(d, a, b, c, w[ 8], S32, 0x8771f681u);
        hh(c, d, a, b, w[11], S33, 0x6d9d6122u);
        hh(b, c, d, a, w[14], S34, 0xfde5380cu);
        hh(a, b, c, d, w[ 1], S31, 0xa4beea44u);
        hh(d, a, b, c, w[ 4], S32, 0x4bdecfa9u);
        hh(c, d, a, b, w[ 7], S33, 0xf6bb4b60u);
        hh(b, c, d, a, w[10], S34, 0xbebfbc70u);
        hh(a, b, c, d, w[13], S31, 0x289b7ec6u);
        hh(d, a, b, c, w[ 0], S32, 0xeaa127fau);
        hh(c, d, a, b, w[ 3], S33, 0xd4ef3085u);
        hh(b, c, d, a, w[ 6], S34, 0x04881d05u);
        hh(a, b, c, d, w[ 9], S31, 0xd9d4d039u);
        hh(d, a, b, c, w[12], S32, 0xe6db99e5u);
        hh(c, d, a, b, w[15], S33, 0x1fa27cf8u);
        hh(b, c, d, a, w[ 2], S34, 0xc4ac5665u);

        // Round 4
        ii(a, b, c, d, w[ 0], S41, 0xf4292244u);
        ii(d, a, b, c, w[ 7], S42, 0x432aff97u);
        ii(c, d, a, b, w[14], S43, 0xab9423a7u);
        ii(b, c, d, a, w[ 5], S44, 0xfc93a039u);
        ii(a, b, c, d, w[12], S41, 0x655b59c3u);
        ii(d, a, b, c, w[ 3], S42, 0x8f0ccc92u);
        ii(c, d, a, b, w[10], S43, 0xffeff47du);
        ii(b, c, d, a, w[ 1], S44, 0x85845dd1u);
        ii(a, b, c, d, w[ 8], S41, 0x6fa87e4fu);
        ii(d, a, b, c, w[15], S42, 0xfe2ce6e0u);
        ii(c, d, a, b, w[ 6], S43, 0xa3014314u);
        ii(b, c, d, a, w[13], S44, 0x4e0811a1u);
        ii(a, b, c, d, w[ 4], S41, 0xf7537e82u);
        ii(d, a, b, c, w[11], S42, 0xbd3af235u);
        ii(c, d, a, b, w[ 2], S43, 0x2ad7d2bbu);
        ii(b, c, d, a, w[ 9], S44, 0xeb86d391u);   
        
        // FINISH HIM!
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
        // FATALITY! \o/
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
        return (x&z)|(y&~z);
    }

    private uint i(uint x, uint y, uint z)
    {
        return y^(x|~z);
    }

    private void ff(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += f(b, c, d) + x + ac;
        a = Bitwise.rotateLeft(a, s);
        a += b;
    }

    private void gg(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += g(b, c, d) + x + ac;
        a = Bitwise.rotateLeft(a, s);
        a += b;
    }

    private void hh(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += h(b, c, d) + x + ac;
        a = Bitwise.rotateLeft(a, s);
        a += b;
    }

    private void ii(ref uint a, uint b, uint c, uint d, uint x, uint s, uint ac)
    {
        a += i(b, c, d) + x + ac;
        a = Bitwise.rotateLeft(a, s);
        a += b;
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
    
    MD5 copy()
    {
        MD5 h = new MD5(buffer[0..index]);
        h.bytes = bytes;
        h.h0 = h0;
        h.h1 = h1;
        h.h2 = h2;
        h.h3 = h3;
        return h;
    }
    
    debug (UnitTest)
    {
        // Found in Tango <3
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
                "d41d8cd98f00b204e9800998ecf8427e",
                "0cc175b9c0f1b6a831c399e269772661",
                "900150983cd24fb0d6963f7d28e17f72",
                "f96b697d7cb7938d525a2f31aaf161d0",
                "c3fcd3d76192e4007dfb496cca67e13b",
                "d174ab98d277d9f5a5611c2c9f419d9f",
                "57edf4a22be3c955ac49da2e2107b67a"
            ];
            
            MD5 h = new MD5();
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
