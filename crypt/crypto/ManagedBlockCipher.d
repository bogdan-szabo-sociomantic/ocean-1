/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.ManagedBlockCipher;

public import ocean.crypt.crypto.BlockCipher;
import ocean.crypt.crypto.BlockCipherPadding;

/** 
 * Wraps a block cipher, enabling the encryption of a stream.
 * Padding, if specified, is to be applied in the finish() call.
 * 
 * Based on PaddedBufferedBlockCipher from BC.
 */
class ManagedBlockCipher : BlockCipher
{
    BlockCipher cipher;
    BlockCipherPadding padding;
    
    protected
    {
        ubyte[] buffer;
        uint index;
        bool encrypt,
             streamMode = false;
    }
    
    /**
     * Create a managed block cipher.
     * 
     * Params:
     *     cipher = Block cipher we're wrapping
     *     padding = Padding or null if no padding
     *     
     * Returns: A new ManagedBlockCipher
     */
    this(BlockCipher cipher, BlockCipherPadding padding=null)
    {
        this.cipher = cipher;
        
        char[] mode = cipher.name;
        int i;
        for (i = 0; i < mode.length; i++)
            if (mode[i] == '/')
                break;
                
        if (i < mode.length)
        {
            mode = mode[i+1..i+4];
            this.streamMode = (mode == "CTR" /*|| mode == "CFB" || mode == "OFB"*/);
        }
        
        this.padding = padding; // null signifies no padding is to be applied
        buffer = new ubyte[blockSize];
    }
    
    void init(bool encrypt, CipherParameters params)
    {
        this.encrypt = encrypt;
        cipher.init(encrypt, params);
    }
     
    char[] name()
    {
        if (padding is null)
            return cipher.name;
            
        return cipher.name~"/"~padding.name;
    }
    
    uint blockSize()
    {
        return cipher.blockSize;
    }
    
    /**
     * Update the cipher object with data from input_ and if it fills
     * a block, place it in output.
     * 
     * Returns: The number of bytes placed in output_.
     */
    uint update(void[] input_, void[] output_)
    {
        ubyte[] input = cast(ubyte[]) input_,
                output = cast(ubyte[]) output_;
        
        if (encrypt && input.length > output.length)
            throw new ShortBufferError("Managed "~name()~": Output buffer too short");
        
        uint result = 0,
             len = input.length,
             diff = buffer.length - index,
             i = 0;
        if (len >= diff)
        {
            buffer[index..buffer.length] = input[i..diff];
            result += cipher.update(buffer, output[i..i+blockSize]);
            index = 0;
            len -= diff;
            i += blockSize;
            
            while (len > blockSize)
            {
                result += cipher.update(input[i..i+blockSize], output[i..i+blockSize]);
                len -= blockSize;
                i += blockSize;
            }
        }
        
        buffer[0..len] = input[i..i+len];
        index += len;
        
        return result;
    }
    
    /**
     * Finalize the cipher, passing all remaining buffered input
     * through the cipher (padding it first, if specified) and
     * subsequently placing it in output_.
     * 
     * Returns: The number of bytes placed in output_.
     */
    uint finish(void[] output_)
    {
        ubyte[] output = cast(ubyte[]) output_;
        uint result = 0;
        if (encrypt)
        {
            if (index == blockSize)
            {
                if (padding !is null && output.length < (blockSize << 1))
                    throw new ShortBufferError("Managed "~name()~": Output buffer too short");
                    
                result += cipher.update(buffer, output[result..result+blockSize]);
                index = 0;
            }

            if (padding !is null)
            {
                uint diff = buffer.length - index;
                buffer[index..buffer.length] = padding.pad(diff);
                index += diff;
            }
            
            if (index)
                result += cipher.update(buffer[0..index], output[result..result+index]);
                
        }
        else // decrypt
        {
            if (streamMode || index == blockSize)
            {
                result += cipher.update(buffer[0..index], buffer[0..index]);
                index = 0;
            }
            else
            {
                reset();
                throw new ShortBufferError(
                        "Managed "~name()~": Padded last block not equal to cipher's blocksize");
            }
            
            try
            {
                if (padding !is null)
                    result -= padding.unpad(buffer);
                    
                output[0..result] = buffer[0..result];
            }
            finally
            {
                reset();
            }
        }
        
        reset();
        
        return result;
    }
    
    /**
     * Params:
     *     len = Number of bytes you plan on passing to update()
     * 
     * Returns: The number of bytes to be output upon a call to update()
     *          with an input length of len bytes. 
     */
    uint updateOutputSize(uint len)
    {
        uint result = len + index;
        return result - (result % blockSize);
    }
    
    /**
     * Params:
     *     len = Number of bytes you plan on passing to update()
     * 
     * Returns: The number of bytes to be output with a call to update()
     *          using an input of len bytes, followed by a call to finish().
     *          This method takes into account padding, mode, etc. Will
     *          return 0 if your input is likely to error (i.e. len is 14
     *          for AES in ECB mode).
     */
    uint finishOutputSize(uint len)
    {
        uint result = len + index,
             diff = result % blockSize;
        
        // Input is a multiple of block size
        if (!diff)
            return ((padding is null) ? result : result+blockSize);
        
        // No padding, return result if stream mode, 0 if not (it'll error)
        if (padding is null)
            return (streamMode ? result : 0);
        
        // Padding, return len(input+padding) if encrypting or 0 if not (it'll error)
        return (encrypt ? result - diff + blockSize : 0);
    }
    
    void reset()
    {
        cipher.reset();
        index = 0;
        buffer[] = 0;
    }
}
