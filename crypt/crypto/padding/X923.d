/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.padding.X923;

import ocean.crypt.crypto.BlockCipherPadding; 

/**
 * This class implements the Null/Zero byte padding described in ANSI X.923.
 * Ex. [... 0x00, 0x00, 0x03]
 */
class X923 : BlockCipherPadding
{
    char[] name()
    {
        return "X923";   
    }
    
    /* Assumes input_ is a multiple of the underlying
     * block cipher's block size.
     */
    ubyte[] pad(uint len)
    {
        ubyte[] output = new ubyte[len];
        
        output[0..len-1] = 0;
        output[output.length-1] = cast(ubyte)len;

        return output;
    }
    
    uint unpad(void[] input_)
    {
        ubyte[] input = cast(ubyte[]) input_;
        
        ubyte len = input[input.length-1];
         
        if (len > input.length || len == 0)
            throw new InvalidPaddingError(name()~": Incorrect padding.");
            
        return len;
    }
}
