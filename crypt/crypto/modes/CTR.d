/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.modes.CTR;

import ocean.crypt.crypto.BlockCipher;
public import ocean.crypt.crypto.params.ParametersWithIV;


/** This class implements the counter (CTR/SIC/ICM) block mode,
    treating the counter as a big endian integer. */
class CTR : BlockCipher
{
    private
    {
        BlockCipher wrappedCipher;
        
        ubyte[] iv,
                counter,
                counterOutput;
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
        return wrappedCipher.name~"/CTR";
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
                    
        wrappedCipher.init(true, ivParams.parameters);
        
        iv = ivParams.iv[0..blockSize];
        counter = new ubyte[blockSize];
        counter[] = iv;
        counterOutput = new ubyte[blockSize];
        
        _initialized = _encrypt = true;
    }
    
    uint update(void[] input_, void[] output_)
    {
        if (!_initialized)
            throw new NotInitializedError(name()~": Block mode not initialized");
            
        ubyte[] input = cast(ubyte[]) input_,
                output = cast(ubyte[]) output_;
                
        uint len = (counter.length > input.length) ? input.length : counter.length;
        
        if (len > output.length)
            throw new ShortBufferError(name()~": Output buffer too short");
        
        // Encrypt the counter
        wrappedCipher.update(counter, counterOutput);
        
        // XOR output with plaintext to create ciphertext
        for (int i = 0; i < len; i++)
            counterOutput[i] ^= input[i];
            
        // Increment the counter
        for (int i = counter.length-1; i >= 0; i--)
            if (++counter[i]) break;

        output[0..len] = counterOutput[0..len];
        
        return len;
    }
    
    uint blockSize()
    {
        return wrappedCipher.blockSize;
    }
    
    void reset()
    {
        counter[] = iv;
        wrappedCipher.reset();
    }
}
