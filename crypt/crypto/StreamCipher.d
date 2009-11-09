/**
 * This file is part of the dcrypt project.
 *
 * Copyright: Copyright (C) dcrypt contributors 2008. All rights reserved.
 * License:   MIT
 * Authors:   Thomas Dixon
 */

module ocean.crypt.crypto.StreamCipher;

public import ocean.crypt.crypto.Cipher;
public import ocean.crypt.crypto.params.CipherParameters;
public import ocean.crypt.crypto.params.SymmetricKey;

/** Interface for a standard stream cipher. */
abstract class StreamCipher : Cipher
{   
    /**
     * Process one byte of input.
     *
     * Params:
     *     input = Byte to XOR with keystream.
     *
     * Returns: One byte of input XORed with the keystream.
     */
    ubyte returnByte(ubyte input);
}
