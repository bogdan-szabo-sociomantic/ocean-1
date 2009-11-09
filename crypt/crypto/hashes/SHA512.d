/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.hashes.SHA512;

public import ocean.crypt.crypto.Hash;

/**
 * Implementation of the US NSA's SHA-512.
 *
 * Conforms: FIPS-180-2
 * References: http://csrc.nist.gov/publications/fips/fips180-2/fips180-2.pdf
 */
class SHA512 : Hash
{
    private static const ulong[] K = [
        0x428a2f98d728ae22u, 0x7137449123ef65cdu, 0xb5c0fbcfec4d3b2fu, 0xe9b5dba58189dbbcu, 
        0x3956c25bf348b538u, 0x59f111f1b605d019u, 0x923f82a4af194f9bu, 0xab1c5ed5da6d8118u, 
        0xd807aa98a3030242u, 0x12835b0145706fbeu, 0x243185be4ee4b28cu, 0x550c7dc3d5ffb4e2u,
        0x72be5d74f27b896fu, 0x80deb1fe3b1696b1u, 0x9bdc06a725c71235u, 0xc19bf174cf692694u, 
        0xe49b69c19ef14ad2u, 0xefbe4786384f25e3u, 0x0fc19dc68b8cd5b5u, 0x240ca1cc77ac9c65u, 
        0x2de92c6f592b0275u, 0x4a7484aa6ea6e483u, 0x5cb0a9dcbd41fbd4u, 0x76f988da831153b5u,
        0x983e5152ee66dfabu, 0xa831c66d2db43210u, 0xb00327c898fb213fu, 0xbf597fc7beef0ee4u, 
        0xc6e00bf33da88fc2u, 0xd5a79147930aa725u, 0x06ca6351e003826fu, 0x142929670a0e6e70u, 
        0x27b70a8546d22ffcu, 0x2e1b21385c26c926u, 0x4d2c6dfc5ac42aedu, 0x53380d139d95b3dfu,
        0x650a73548baf63deu, 0x766a0abb3c77b2a8u, 0x81c2c92e47edaee6u, 0x92722c851482353bu, 
        0xa2bfe8a14cf10364u, 0xa81a664bbc423001u, 0xc24b8b70d0f89791u, 0xc76c51a30654be30u,
        0xd192e819d6ef5218u, 0xd69906245565a910u, 0xf40e35855771202au, 0x106aa07032bbd1b8u,
        0x19a4c116b8d2d0c8u, 0x1e376c085141ab53u, 0x2748774cdf8eeb99u, 0x34b0bcb5e19b48a8u,
        0x391c0cb3c5c95a63u, 0x4ed8aa4ae3418acbu, 0x5b9cca4f7763e373u, 0x682e6ff3d6b2b8a3u,
        0x748f82ee5defb2fcu, 0x78a5636f43172f60u, 0x84c87814a1f0ab72u, 0x8cc702081a6439ecu,
        0x90befffa23631e28u, 0xa4506cebde82bde9u, 0xbef9a3f7b2c67915u, 0xc67178f2e372532bu,
        0xca273eceea26619cu, 0xd186b8c721c0c207u, 0xeada7dd6cde0eb1eu, 0xf57d4f7fee6ed178u,
        0x06f067aa72176fbau, 0x0a637dc5a2c898a6u, 0x113f9804bef90daeu, 0x1b710b35131c471bu,
        0x28db77f523047d84u, 0x32caab7b40c72493u, 0x3c9ebe0a15c9bebcu, 0x431d67c49c100d4cu, 
        0x4cc5d4becb3e42b6u, 0x597f299cfc657e2au, 0x5fcb6fab3ad6faecu, 0x6c44198c4a475817u
    ];
    
    protected ulong h0, h1, h2, h3, h4, h5, h6, h7;
    
    this (void[] input_=null)
    {
        reset();
        super(input_);
    }

    uint blockSize()
    {
        return 128;
    }
    
    uint digestSize()
    {
        return 64;
    }
    
    char[] name()
    {
        return "SHA512";
    }
    
    void transform(ubyte[] input)
    {
        ulong[] w = new ulong[80];
        
        for (int i = 0, j = 0; i < 16; i++,j+=long.sizeof)
            w[i] = ByteConverter.BigEndian.to!(ulong)(input[j..j+long.sizeof]);
        
        for (int i = 16; i < 80; i++)
            w[i] = theta1(w[i-2]) + w[i-7] + theta0(w[i-15]) + w[i-16];
        
        ulong a = h0,
              b = h1,
              c = h2,
              d = h3,
              e = h4,
              f = h5,
              g = h6,
              h = h7;
        
        for (int i = 0; i < 80; i++)
        {
            ulong t1 = h + sum1(e) + ch(e,f,g) + K[i] + w[i],
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
    
    private ulong ch(ulong x, ulong y, ulong z)
    {
            return (x&y)^(~x&z);
    }
    
    private ulong maj(ulong x, ulong y, ulong z)
    {
            return (x&y)^(x&z)^(y&z);
    }

    private ulong sum0(ulong x)
    {
            return (Bitwise.rotateRight(x,28)^
                    Bitwise.rotateRight(x,34)^
                    Bitwise.rotateRight(x,39));
    }

    private ulong sum1(ulong x)
    {
            return (Bitwise.rotateRight(x,14)^
                    Bitwise.rotateRight(x,18)^
                    Bitwise.rotateRight(x,41));
    }

    private ulong theta0(ulong x)
    {
        return Bitwise.rotateRight(x,1)^Bitwise.rotateRight(x,8)^(x >> 7);
    }

    private ulong theta1(ulong x)
    {
        return Bitwise.rotateRight(x,19)^Bitwise.rotateRight(x,61)^(x >> 6);
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
        result[48..56] = ByteConverter.BigEndian.from!(ulong)(h6);
        result[56..64] = ByteConverter.BigEndian.from!(ulong)(h7);

        reset();
        return result;
    }

    void reset()
    {
        super.reset();
        h0 = 0x6a09e667f3bcc908u;
        h1 = 0xbb67ae8584caa73bu;
        h2 = 0x3c6ef372fe94f82bu;
        h3 = 0xa54ff53a5f1d36f1u;
        h4 = 0x510e527fade682d1u;
        h5 = 0x9b05688c2b3e6c1fu;
        h6 = 0x1f83d9abfb41bd6bu;
        h7 = 0x5be0cd19137e2179u;
    }
    
    SHA512 copy()
    {
        SHA512 h = new SHA512(buffer[0..index]);
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
                "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce"~
                "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
                
                "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"~
                "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
                
                "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018"~
                "501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909",
                
                "e718483d0ce769644e2e42c7bc15b4638e1f98b13b2044285632a803afa973eb"~
                "de0ff244877ea60a4cb0432ce577c31beb009c5c2c49aa2e4eadb217ad8cc09b"
            ];

            SHA512 h = new SHA512();
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
