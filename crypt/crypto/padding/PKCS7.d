/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.padding.PKCS7;

import ocean.crypt.crypto.BlockCipherPadding; 

/**
 * This class implements the padding scheme described in PKCS7
 * from RSA Security. Ex. [... 0x03, 0x03, 0x03]
 */
class PKCS7 : BlockCipherPadding
{
    char[] name()
    {
        return "PKCS7";   
    }
    
    ubyte[] pad(uint len)
    {
        ubyte[] output = new ubyte[len];
        
        output[0..output.length] = cast(ubyte)len;

        return output;
    }
    
    uint unpad(void[] input_)
    {
        ubyte[] input = cast(ubyte[]) input_;
        
        ubyte len = input[input.length-1];
         
        if (len > input.length || len == 0)
            throw new InvalidPaddingError(name()~": Incorrect padding.");
        
        uint limit = input.length;
        for (int i = 0; i < len; i++)
            if (input[--limit] != len)
                throw new InvalidPaddingError(name()~": Pad value does not match pad length.");
                        
        return len;
    }
}
