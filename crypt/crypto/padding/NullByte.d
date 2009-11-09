/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.padding.NullByte;

import ocean.crypt.crypto.BlockCipherPadding; 

/**
 * This class implements Null/Zero byte padding.
 * Ex. [... 0x00, 0x00 ... 0x00]
 */
class NullByte : BlockCipherPadding {
    char[] name()
    {
        return "NullByte";   
    }
    
    ubyte[] pad(uint len)
    {
        ubyte[] output = new ubyte[len];
        
        output[0..output.length] = 0;

        return output;
    }
    
    uint unpad(void[] input_)
    {
        ubyte[] input = cast(ubyte[]) input_;
        
        uint len = input.length;
        while (len-- > 0)
            if (input[len-1] != 0) break;
            
        return (input.length - len);
    }
}
