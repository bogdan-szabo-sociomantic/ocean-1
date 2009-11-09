/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.prngs.PRNGFromHash;

import ocean.crypt.crypto.PRNG;
import ocean.crypt.crypto.Hash;

/** Creates a PRNG from a hash function. */
class PRNGFromHash : PRNG
{
    private
    {
        const uint COUNTER_SIZE = 32;
        
        Hash hash;
        ubyte[] counter,
                seed,
                state;
        uint index;
    }
    
    char[] name()
    {
        if (hash is null)
            throw new NotInitializedError(name()~": PRNG not initialized.");
        
        return hash.name~"PRNG";
    }
    
    this(Hash hash)
    {
        if (hash is null)
            throw new InvalidParameterError(
                name()~": Invalid parameter passed to constructor.");
                
        this.hash = hash;
        this.hash.reset();
        
        counter = new ubyte[COUNTER_SIZE];
        seed = new ubyte[this.hash.digestSize];
        state = new ubyte[this.hash.digestSize];
        
        index = this.hash.digestSize; // to force updating of the state
    }
    
    void addEntropy(void[] input)
    {
        if (!_initialized)
        {
            hash.update(input);
            seed = hash.digest();
            _initialized = true;
        } else
            throw new NotSupportedError(name()~": state is immutable once initialized.");
    }
    
    uint read(void[] output_)
    {
        if (!_initialized)
            throw new NotInitializedError(name()~": PRNG not initialized.");
            
        ubyte[] output = cast(ubyte[])output_;
        
        for (uint i = 0; i < output.length; i++)
        {
            if (index == state.length)
            {
                hash.update(seed);
                hash.update(counter);
                state = hash.digest();
                
                // Increment the counter
                for (uint j = COUNTER_SIZE-1; j >= 0; j--)
                    if (++counter[j]) break;
                
                index = 0;
            }
            output[i] = state[index++];
        }
        
        return output.length;
    }
}
