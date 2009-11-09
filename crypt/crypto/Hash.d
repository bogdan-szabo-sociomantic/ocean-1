/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.Hash;

public import ocean.crypt.misc.ByteConverter;
public import ocean.crypt.misc.Bitwise;

/** Base class for all cryptographic hash functions */
class Hash
{
    private const enum
    {
        MODE_MD=0, // MDx, RipeMD, etc
        MODE_SHA,
        MODE_TIGER
    }
    
    protected
    {
        ubyte[] buffer;
        ulong bytes;
        uint index;
    }
        
    this (void[] input_=null)
    {
        buffer = new ubyte[blockSize];
        ubyte[] input = cast(ubyte[]) input_;
        if (input)
            update(input);
    }
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        this (char[] input_)
        {
            this(cast(ubyte[])input_);
        }
    }
    
    /** Returns: The block size of the hash function in bytes. */
    abstract uint blockSize();
    
    /** Returns: The output size of the hash function in bytes. */
    abstract uint digestSize();
    
    /** Returns: The name of the algorithm we're implementing. */
    abstract char[] name();
    
    /** Returns: A copy of this hash object. */
    abstract Hash copy();

    /**
     * Introduce data into the hash function.
     * 
     * Params:
     *     input_ = Data to be processed.
     *     
     * Returns: Self
     */
    Hash update(void[] input_)
    {
        ubyte[] input = cast(ubyte[]) input_;
        uint i, partLength;
        
        index = bytes & (blockSize - 1);
        bytes += input.length;
        
        partLength = blockSize - index;
        
        if (input.length >= partLength)
        {
            buffer[index..index+partLength] = input[0..partLength];
            transform(buffer);
            
            for (i = partLength; i + (blockSize - 1) < input.length; i+=blockSize)
                transform(input[i..i+blockSize]);
                
            index = 0;
        }
        else
            i = 0;
            
        if (input.length - i)
            buffer[index..index+(input.length-i)] = input[i..input.length];
        
        return this;
    }
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        Hash update(char[] input_)
        {
            return update(cast(ubyte[])input_);
        }
    }
    
    /** Hash function's internal transformation. */
    protected abstract void transform(ubyte[] input);
    
    /** 
     * Pad message in the respective manner.
     * 
     * Params:
     *     mode = Mode constant dictating in which manner
     *            to pad the message.
     */
    protected void padMessage(uint mode)
    {
        ulong bits = bytes << 3;
        index = bytes & (blockSize - 1);
        
        // Add the pad marker
        buffer[index++] = ((mode == MODE_TIGER) ? 0x01 : 0x80);
        if (index == blockSize)
        {
            transform(buffer);
            index = 0;
        }
        
        // Pad with null bytes
        while ((index & (blockSize - 1)) != (blockSize - (blockSize >> 3)))
        {
            buffer[index++] = 0;
            
            if (index == blockSize)
            {
                transform(buffer);
                index = 0;
            }
        }
        
        // Length padding
        for (int i = 0; i < blockSize; i+=8, bits>>=8) // little endian
                buffer[index++] = bits;
                                
        if (mode == MODE_SHA)
            buffer[(buffer.length-(blockSize >> 3))..buffer.length].reverse; // big endian

        transform(buffer);
        index = 0;
    }
    
    /**
     * Process all data, pad and finalize. This method will
     * reset the digest to its original state for subsequent use.
     * 
     * Returns: Binary representation of the hash in bytes.
     */
    abstract ubyte[] digest();
    
    /**
     * Same as digest() but returns hash value in hex.
     * 
     * Returns: Representation of the final hash value in hex.
     */
    char[] hexDigest()
    {
        return ByteConverter.hexEncode(digest());
    }
    
    /** Reset hash to initial state. */
    void reset()
    {
        bytes = index = 0;
    }
}
