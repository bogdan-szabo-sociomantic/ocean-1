/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.modes.CBC;

import ocean.crypt.crypto.BlockCipher;
public import ocean.crypt.crypto.params.ParametersWithIV;

debug (UnitTest)
{
    import ocean.crypt.crypto.ciphers.XTEA;
    import ocean.crypt.misc.ByteConverter;
}

/** This class implements the cipher block chaining (CBC) block mode. */
class CBC : BlockCipher
{
    private
    {
         BlockCipher wrappedCipher;
         
         ubyte[] iv,
                 previousBlock,
                 currentBlock;
    }
    
    /**
     * Params:
     *     cipher = Block cipher to wrap.
     */
    this (BlockCipher cipher)
    {
        wrappedCipher = cipher;
    }
    
    /** Returns: The underlying cipher we are wrapping. */
    BlockCipher cipher()
    {
        return wrappedCipher;
    }
    
    char[] name()
    {
        return wrappedCipher.name~"/CBC";
    }
    
    /** 
     * Throws: dcrypt.crypto.errors.InvalidParameterError if params aren't 
     *         an instance of dcrypt.crypto.params.ParametersWithIV.
     */
    void init(bool encrypt, CipherParameters params)
    {
        ParametersWithIV ivParams = cast(ParametersWithIV)params;
        
        if (!ivParams)
            throw new InvalidParameterError(
                    name()~": Block mode requires IV (use ParametersWithIV)");
        if (ivParams.iv.length != blockSize)
            throw new InvalidParameterError(
                    name()~": IV must be same length as cipher block size");
                    
        _encrypt = encrypt;
        
        wrappedCipher.init(_encrypt, ivParams.parameters);
        
        iv = ivParams.iv[0..blockSize];
        
        currentBlock = new ubyte[blockSize];
        previousBlock = new ubyte[blockSize];
        previousBlock[] = iv; // C_0 = IV
        
        _initialized = true;
    }
    
    uint update(void[] input_, void[] output_)
    {
        if (!_initialized)
            throw new NotInitializedError(name()~": Block mode not initialized");
            
        ubyte[] input = cast(ubyte[]) input_,
                output = cast(ubyte[]) output_;
                    
        if (input.length < blockSize)
            throw new ShortBufferError(name()~": Input buffer too short");
            
        if (output.length < blockSize)
            throw new ShortBufferError(name()~": Output buffer too short");
        
        if (_encrypt)
        {
            // P_i XOR C_i-1
            for (int i = 0; i < blockSize; i++)
                previousBlock[i] ^= input[i];
                
            // E_k(P_i XOR C_i-1) and store C_i for the next block
            wrappedCipher.update(previousBlock, previousBlock);
            
            // C_i = E_k(P_i XOR C_i-1)
            output[0..blockSize] = previousBlock;            
        }
        else
        {
            // Local reference to C_i
            ubyte[] temp = input[0..blockSize];

            // D_k(C_i)
            wrappedCipher.update(temp, currentBlock);
            
            // P_i = D_k(C_i) XOR C_i-1
            for (int i = 0; i < blockSize; i++)
                output[i] = (currentBlock[i] ^ previousBlock[i]);
             
            // Store C_i for next block
            previousBlock[] = temp;
       }
        
        return blockSize;
    }
    
    uint blockSize()
    {
        return wrappedCipher.blockSize;
    }
    
    void reset()
    {
        previousBlock[] = iv;
        wrappedCipher.reset();
    }
    
    /** Test vectors for CBC mode. Assumes XTEA passes test vectors. */
    debug (UnitTest)
    {
        unittest
        {
            static const char[][] test_keys = [
                "00000000000000000000000000000000",            
                "00000000000000000000000000000000",
                "0123456789abcdef0123456789abcdef"
            ];
                 
            static const char[][] test_plaintexts = [
                "00000000000000000000000000000000"~
                "00000000000000000000000000000000",
                 
                "41414141414141414141414141414141"~
                "41414141414141414141414141414141",
                 
                "01010101010101010101010101010101"~
                "01010101010101010101010101010101"
            ];

            static const char[][] test_ciphertexts = [
                "dee9d4d8f7131ed9b0e40a036a85d2c4"~
                "4602d6e67f0c603738197998166ef281",
                 
                "ed23375a821a8c2d0e1f03d719874eaa"~
                "4b71be74f261e22f4cd2285883a61a23",
                 
                "c09d3c606614d84b8d184fa29c5cb5f6"~
                "f26fa5a0b6b63ba0f7ebf2f8735f85e3"
            ];

            CBC c = new CBC(new XTEA);
            ubyte[] iv = new ubyte[c.blockSize], // Initialized to 0
                    buffer = new ubyte[32];
            char[] result;
            for (int i = 0; i < test_keys.length; i++)
            {
                SymmetricKey key = new SymmetricKey(ByteConverter.hexDecode(test_keys[i]));
                ParametersWithIV params = new ParametersWithIV(key, iv);
                
                // Encryption
                c.init(true, params);
                for (int j = 0; j < 32; j+=c.blockSize)
                    c.update(ByteConverter.hexDecode(test_plaintexts[i])[j..j+c.blockSize], buffer[j..j+c.blockSize]);
                result = ByteConverter.hexEncode(buffer);
                assert(result == test_ciphertexts[i],
                        c.name()~": ("~result~") != ("~test_ciphertexts[i]~")");           
                
                // Decryption
                c.init(false, params);
                for (int j = 0; j < 32; j+=c.blockSize)
                    c.update(ByteConverter.hexDecode(test_ciphertexts[i])[j..j+c.blockSize], buffer[j..j+c.blockSize]);
                result = ByteConverter.hexEncode(buffer);
                assert(result == test_plaintexts[i],
                        c.name()~": ("~result~") != ("~test_plaintexts[i]~")");
            }   
        }
    }
}
