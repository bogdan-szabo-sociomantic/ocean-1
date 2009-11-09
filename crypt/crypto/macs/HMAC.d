/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.macs.HMAC;

import ocean.crypt.crypto.MAC;
import ocean.crypt.crypto.Hash;
import ocean.crypt.crypto.params.SymmetricKey;
import ocean.crypt.crypto.errors.NotInitializedError;

debug (UnitTest)
{
    import ocean.crypt.crypto.hashes.SHA1;
}

/** 
 * Implementation of Keyed-Hash Message Authentication Code (HMAC)
 * 
 * Conforms: RFC 2104 
 * References: http://www.faqs.org/rfcs/rfc2104.html
 */
class HMAC : MAC
{
    private
    {
        ubyte[] ipad, opad, key;
        Hash hash;
        bool initialized;
    }
    
    this (Hash hash, void[] key=null)
    {
        this.hash = hash.copy();
        this.hash.reset();
        
        ipad = new ubyte[blockSize];
        opad = new ubyte[blockSize];
        
        if (key)
            init(new SymmetricKey(key)); // I'm lazy.
    }
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        this (Hash hash, char[] key)
        {
            this(hash, cast(ubyte[])key);
        }
    }
    
    void init(CipherParameters params)
    {
        SymmetricKey keyParams = cast(SymmetricKey)params;
        if (!keyParams)
            throw new InvalidParameterError(
                    name()~": Invalid parameter passed to init");
        
        hash.reset();
        
        if (keyParams.key.length > blockSize)
        {
            hash.update(keyParams.key);
            key = hash.digest();
        } else
            key = keyParams.key;
        
        ipad[] = 0x36;
        opad[] = 0x5c;
        
        foreach (uint i, ubyte j; key)
        {
            ipad[i] ^= j;
            opad[i] ^= j;
        }
        
        reset();
        
        initialized = true;
    }
    
    void update(void[] input_)
    {
        if (!initialized)
            throw new NotInitializedError(name()~": MAC not initialized.");
            
        hash.update(input_);
    }
    
    char[] name()
    {
        return "HMAC-"~hash.name;
    }
    
    void reset()
    {    
        hash.reset();
        hash.update(ipad);
    }
    
    uint blockSize()
    {
        return hash.blockSize;
    }
    
    uint macSize()
    {
        return hash.digestSize;
    }
    
    ubyte[] digest()
    {
        ubyte[] t = hash.digest();
        hash.update(opad);
        hash.update(t);
        ubyte[] r = hash.digest();
        
        reset();
        
        return r;
    }
    
    char[] hexDigest()
    {
        return ByteConverter.hexEncode(digest());
    }
    
    HMAC copy()
    {
        // Ghetto... oh so ghetto :\
        HMAC h = new HMAC(hash.copy());
        h.hash = hash.copy();
        h.initialized = true;
        return h;
    }
    
    debug (UnitTest)
    {
        unittest
        {
            static char[][] test_keys = [
                "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b",
                "4a656665", // Jefe?
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
                "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
            ];
            
            static char[][] test_inputs = [
                "4869205468657265",
                "7768617420646f2079612077616e7420666f72206e6f7468696e673f",
                "dd",
                "54657374205573696e67204c6172676572205468616e20426c6f63"~
                "6b2d53697a65204b6579202d2048617368204b6579204669727374"
            ];
            
            static int[] test_repeat = [
                1, 1, 50, 1
            ];
            
            static char[][] test_results = [
                "b617318655057264e28bc0b6fb378c8ef146be00",
                "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79",
                "125d7342b9ac11cd91a39af48aa17b4f63f175d3",
                "aa4ae5e15272d00e95705637ce8a3b55ed402112"
            ];
            
            HMAC h = new HMAC(new SHA1());
            foreach (uint i, char[] k; test_keys)
            {
                h.init(new SymmetricKey(ByteConverter.hexDecode(k)));
                for (int j = 0; j < test_repeat[i]; j++)
                    h.update(ByteConverter.hexDecode(test_inputs[i]));
                char[] mac = h.hexDigest();
                assert(mac == test_results[i], 
                        h.name~": ("~mac~") != ("~test_results[i]~")");
            }
        }
    }
}
