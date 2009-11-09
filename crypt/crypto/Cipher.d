/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.Cipher;

public import ocean.crypt.crypto.errors.InvalidKeyError;
public import ocean.crypt.crypto.errors.ShortBufferError;
public import ocean.crypt.crypto.errors.NotInitializedError;
public import ocean.crypt.crypto.errors.InvalidParameterError;

public import ocean.crypt.crypto.params.CipherParameters;

/** Base symmetric cipher class */
abstract class Cipher
{
    static const bool ENCRYPT = true,
                      DECRYPT = false;
                      
    protected bool _initialized,
                   _encrypt;
    
    /**
     * Initialize a cipher.
     * 
     * Params:
     *     encrypt = True if we are encrypting.
     *     params  = Parameters to be passed to the cipher. (Key, rounds, etc.)
     */
    void init(bool encrypt, CipherParameters params);
    
    /**
     * Process a block of plaintext data from the input array
     * and place it in the output array.
     *
     * Params:
     *     input_  = Array containing input data.
     *     output_  = Array to hold the output data.
     *
     * Returns: The amount of encrypted data processed.
     */
    uint update(void[] input_, void[] output_);
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        uint update(char[] input_, void[] output_)
        {
            return update(cast(ubyte[])input_, output_);
        }
    }
    
    /** Returns: The name of the algorithm of this cipher. */
    char[] name();
    
    /** Returns: Whether or not the cipher has been initialized. */
    bool initialized()
    {
        return _initialized;
    }
    
    /** Reset cipher to its state immediately subsequent the last init. */
    void reset();
}
