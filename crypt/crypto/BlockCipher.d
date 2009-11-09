/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */
 
module ocean.crypt.crypto.BlockCipher;

public import ocean.crypt.crypto.Cipher;
public import ocean.crypt.crypto.params.SymmetricKey;

/** Interface for a standard block cipher. */
abstract class BlockCipher : Cipher
{
    
    /** Returns: The block size in bytes that this cipher will operate on. */
    uint blockSize();
}
