/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.MAC;

public import ocean.crypt.crypto.params.CipherParameters;
public import ocean.crypt.crypto.params.SymmetricKey;
public import ocean.crypt.crypto.errors.InvalidParameterError;
import ocean.crypt.misc.ByteConverter;

/** Base MAC class */
abstract class MAC
{
    /**
     * Initialize a MAC.
     * 
     * Params:
     *     params  = Parameters to be passed to the MAC. (Key, etc.)
     */
    void init(CipherParameters params);
    
    /**
     * Introduce data into the MAC.
     * 
     * Params:
     *     input_ = Data to be processed.
     */
    void update(void[] input_);
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        void update(char[] input_)
        {
            update(cast(ubyte[])input_);
        }
    }
    
    /** Returns: The name of this MAC. */
    char[] name();
    
    /** Reset MAC to its state immediately subsequent the last init. */
    void reset();
    
    /** Returns: The block size in bytes that this MAC will operate on. */
    uint blockSize();
    
    /** Returns: The output size of the MAC in bytes. */
    uint macSize();
    
    /** Returns: The computed MAC. */
    ubyte[] digest();
    
    /** Returns: The computed MAC in hexadecimal. */
    char[] hexDigest()
    {
        return ByteConverter.hexEncode(digest());
    }
}
