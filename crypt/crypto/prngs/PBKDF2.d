/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.prngs.PBKDF2;

import ocean.crypt.misc.ByteConverter;
import ocean.crypt.crypto.PRNG;
import ocean.crypt.crypto.MAC;
import ocean.crypt.crypto.macs.HMAC;
import ocean.crypt.crypto.hashes.SHA1;
import ocean.crypt.crypto.errors.LimitReachedError;

/**
 * Implementation of RSA Security's Password-Based Key Derivation Function 2
 * 
 * Conforms: PKCS #5 v2.0 / RFC 2898
 * References: http://www.truecrypt.org/docs/pkcs5v2-0.pdf
 */
class PBKDF2 : PRNG
{
    private
    {
        ubyte[] salt,
                buffer;
        
        char[] password;
        
        MAC prf;
        
        uint iterations,
             blockCount,
             index;
    }
    
    /**
     * Params:
     *     password = User supplied password
     *     salt = (preferably random) salt
     *     iterations = The number of total iterations
     *     prf = The pseudo-random function
     */
    this (char[] password, void[] salt_, uint iterations=1000, MAC prf=new HMAC(new SHA1))
    {
        
        salt = cast(ubyte[])salt_;
        if (salt == null)
            throw new InvalidParameterError(name()~": No salt specified.");
        
        this.password = password;
        if (this.password == null)
            throw new InvalidParameterError(name()~": No password specified.");
        
        this.prf = prf;
        if (this.prf is null)
            throw new InvalidParameterError(name()~": No PRF specified.");
        
        this.iterations = iterations;
        
        prf.init(new SymmetricKey(cast(ubyte[])this.password));
        blockCount = 0;
        buffer = new ubyte[this.prf.macSize];
        index = this.prf.macSize;
        
        _initialized = true;
    }
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        this (char[] password, char[] salt, uint iterations=1000, MAC prf=new HMAC(new SHA1))
        {
            this(password, cast(ubyte[])salt, iterations, prf);
        }
    }
    
    void addEntropy(void[] input)
    {
        throw new NotSupportedError(name()~": addEntropy is not supported.");
    }
    
    /**
     * Throws: LimitReachedError after 2^32 blocks.
     */
    uint read(void[] output_)
    {
        ubyte[] output = cast(ubyte[])output_;
        
        for (uint i = 0; i < output.length; i++)
        {
            if (index == buffer.length)
            {
                if (++blockCount == 0) // Catch rollover
                    throw new LimitReachedError(name()~": Output limit reached.");
                
                buffer[] = 0;
                
                ubyte[] t = new ubyte[salt.length + uint.sizeof];
                t[0..salt.length] = salt;
                t[salt.length..salt.length+int.sizeof] = ByteConverter.BigEndian.from!(uint)(blockCount);
                
                for (uint j = 0; j < iterations; j++)
                {
                    prf.reset();
                    prf.update(t);
                    t = prf.digest();
                    
                    for (uint k = 0; k < buffer.length; k++)
                        buffer[k] ^= t[k];
                }
                
                index = 0;
            }
            
            output[i] = buffer[index++];
        }

        return output.length;
    }
    
    char[] name()
    {
        return "PBKDF2-"~prf.name;
    }

    debug (UnitTest)
    {
        unittest
        {
            static char[][] test_passwords = [
                "password",
                "password",
                "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"~
                "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"~
                "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
            ];
            
            static char[][] test_salts = [
                "ATHENA.MIT.EDUraeburn",
                "ATHENA.MIT.EDUraeburn",
                "pass phrase equals block size",
                "pass phrase exceeds block size"
            ];
            
            static int[] test_iterations = [
                1, 1200, 1200, 1200
            ];
            
            static char[][] test_results = [
                "cdedb5281bb2f801565a1122b2563515",
                "5c08eb61fdf71e4e4ec3cf6ba1f5512b"~
                "a7e52ddbc5e5142f708a31e2e62b1e13",
                "139c30c0966bc32ba55fdbf212530ac9"~
                "c5ec59f1a452f5cc9ad940fea0598ed1",
                "9ccad6d468770cd51b10e6a68721be61"~
                "1a8b4d282601db3b36be9246915ec82a"
            ];
            
            PBKDF2 pbkdf2;
            foreach (uint i, char[] p; test_passwords)
            {
                pbkdf2 = new PBKDF2(p, test_salts[i], test_iterations[i]);
                ubyte[] result = new ubyte[test_results[i].length >> 1];
                pbkdf2.read(result);
                char[] hexResult = ByteConverter.hexEncode(result);
                assert(hexResult == test_results[i], 
                        pbkdf2.name~": ("~hexResult~") != ("~test_results[i]~")");
            }
        }
    }   
}
