/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.params.SymmetricKey;

import ocean.crypt.crypto.params.CipherParameters;
import ocean.crypt.crypto.errors.InvalidParameterError;

/** Object representing and wrapping a symmetric key in bytes. */
class SymmetricKey : CipherParameters
{
    private ubyte[] _key;
    
    /**
     * Params:
     *     key = Key to be held.
     */
    this(void[] key=null)
    {
        _key = cast(ubyte[]) key;
    }
    
    /** Play nice with D2's idea of const. */
    version (D_Version2)
    {
        this (char[] key)
        {
            this(cast(ubyte[])key);
        }
    }
    
    /** Returns: Key in ubytes held by this object. */
    ubyte[] key()
    {
        return _key;
    }
    
    /**
     * Set the key held by this object.
     *
     * Params:
     *     newKey = New key to be held.
     * Returns: The new key.
     */
    ubyte[] key(void[] newKey)
    {
        return _key = cast(ubyte[]) newKey;
    }
}
