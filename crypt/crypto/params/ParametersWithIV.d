/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

moduleocean.crypt.crypto.params.ParametersWithIV;

public import ocean.crypt.crypto.params.CipherParameters;

/** Wrap cipher parameters and IV. */
class ParametersWithIV : CipherParameters
{
    private ubyte[] _iv;
    private CipherParameters _params;
    
    /**
     * Params:
     *     params = Parameters to wrap.
     *     iv     = IV to be held.
     */
    this (CipherParameters params=null, void[] iv=null)
    {
        _params = params;
        _iv = cast(ubyte[]) iv;
    }
    
    /** Returns: The IV. */
    ubyte[] iv()
    {
        return _iv;
    }
    
    /**
     * Set the IV held by this object.
     *
     * Params:
     *     newIV = The new IV for this parameter object.
     * Returns: The new IV.
     */
    ubyte[] iv(void[] newIV)
    {
        return _iv = cast(ubyte[]) newIV;
    }
    
    /** Returns: The parameters for this object. */
    CipherParameters parameters()
    {
        return _params;
    }
    
    /**
     * Set the parameters held by this object.
     *
     * Params:
     *     newParams = The new parameters to be held.
     * Returns: The new parameters.
     */
    CipherParameters parameters(CipherParameters newParams)
    {
        return _params = newParams;
    }
}
