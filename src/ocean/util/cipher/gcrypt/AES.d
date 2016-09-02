/*******************************************************************************

    libgcrypt with algorithm AES (Rijndael) with a 128 bit key.

    Requires linking with libgcrypt:
            -L -lgcrypt

    See_Also:
        http://csrc.nist.gov/publications/fips/fips197/fips-197.pdf

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.AES;

import ocean.util.cipher.gcrypt.core.Gcrypt;
import ocean.transition;


/*******************************************************************************

    Gcrypt with AES with mode ECB.

    See usage example in unittest below.

*******************************************************************************/

public alias GcryptNoIV!(Algorithm.GCRY_CIPHER_AES, Mode.GCRY_CIPHER_MODE_ECB) AES;

version ( UnitTest )
{
    import ocean.core.Test;
}

/// Usage example
unittest
{
    // AES requires a key of length 16 bytes.
    auto key = cast(Immut!(ubyte)[])"asdfghjklqwertyu";

    // AES requires the text of 16-bytes blocks.
    istring text = "Length divide 16";
    mstring encrypted_text, decrypted_text;

    // Create the class.
    auto two = new AES(key);

    // encryption/decryption is done in place so first copy the plain text to a
    // buffer.
    encrypted_text ~= text;

    // The actual encryption.
    two.encrypt(encrypted_text);

    // Since decryption is done in place we copy the decrypted string to a new
    // buffer.
    decrypted_text ~= encrypted_text;

    // The decryption call.
    two.decrypt(decrypted_text);

    // We have now successfully encrypted and decrypted a string.
    test!("==")(text, decrypted_text);
}
