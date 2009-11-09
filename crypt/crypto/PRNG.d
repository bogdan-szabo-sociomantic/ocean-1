/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.PRNG;

public import ocean.crypt.crypto.errors.ShortBufferError;
public import ocean.crypt.crypto.errors.NotInitializedError;
public import ocean.crypt.crypto.errors.InvalidParameterError;
public import ocean.crypt.crypto.errors.NotSupportedError;

/** Relatively simple interface for PRNGs. */
abstract class PRNG
{
    
    protected bool _initialized;
    
    /** Returns: Whether or not the PRNG has been initialized. */
    bool initialized()
    {
        return _initialized;
    }
    
    /**
     * Introduce entropy into the PRNG. An initial call to this is
     * usually required for seeding.
     * 
     * Params:
     *     input = Bytes to introduce into the PRNG as entropy
     */
    void addEntropy(void[] input);
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        void addEntropy(char[] input)
        {
            addEntropy(cast(ubyte[])input);
        }
    }
    
    /**
     * Read bytes from the keystream of the PRNG into output.
     * 
     * Params:
     *     output = Array to fill with the next bytes of the keystream
     */
    uint read(void[] output_);
    
    /** Returns: The name of the PRNG algorithm */
    char[] name();
}
