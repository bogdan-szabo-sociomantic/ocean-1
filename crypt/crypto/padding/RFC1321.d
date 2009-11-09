/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.padding.RFC1321;

import ocean.crypt.crypto.BlockCipherPadding; 

/** 
 * This class implements the padding described in RFC1321 (MD5 spec).
 * Ex. [... 0x80, 0x00 ... 0x00]
 */
class RFC1321 : BlockCipherPadding
{
    char[] name()
    {
        return "RFC1321";   
    }

    ubyte[] pad(uint len)
    {
        ubyte[] output = new ubyte[len];
        
        output[0] = 0x80;
        output[1..output.length] = 0;

        return output;
    }
    
    uint unpad(void[] input_)
    {
        ubyte[] input = cast(ubyte[]) input_;
        
        uint len = input.length;
        
        while (len-- > 0)
            if (input[len] != 0) break;
            
        if (input[len] != 0x80)
            throw new  InvalidPaddingError(name()~": Incorrect padding.");
                    
        return (input.length - len);
    }
}
