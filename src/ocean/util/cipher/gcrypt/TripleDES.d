/*******************************************************************************

    libgcrypt with algorithm 3DES and mode CFB

    Requires linking with libgcrypt:
            -L-lgcrypt

    See_Also:
        https://en.wikipedia.org/wiki/Triple_DES
        https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.TripleDES;

import ocean.util.cipher.gcrypt.core.Gcrypt;
import ocean.transition;


/*******************************************************************************

    Gcrypt with 3DES with mode CFB.

    See usage example in unittest below.

*******************************************************************************/

public alias Gcrypt!(Algorithm.GCRY_CIPHER_3DES, Mode.GCRY_CIPHER_MODE_CFB) TripleDES;

version ( UnitTest )
{
    import ocean.core.Test;
}

/// Usage example
unittest
{
    // TripleDES requires a key of length 24 bytes
    auto key = cast(Immut!(ubyte)[])"a key of 24 bytesa key o";
    // TripleDES requires an initialisation vector of length 8 bytes.
    auto iv = cast(Immut!(ubyte)[])"iv8bytes";

    istring text = "This is a text we are going to encrypt";
    mstring encrypted_text, decrypted_text;

    // Create the class
    auto two = new TripleDES(key);

    // encryption/decryption is done in place so first copy the plain text to a
    // buffer.
    encrypted_text ~= text;

    // The actual encryption.
    two.encrypt(encrypted_text, iv);

    // Since decryption is done in place we copy the decrypted string to a new
    // buffer.
    decrypted_text ~= encrypted_text;

    // The decryption call
    two.decrypt(decrypted_text, iv);

    // We have now successfully encrypted and decrypted a string.
    test!("==")(text, decrypted_text);
}


/*******************************************************************************

    Instantiate the class to run the unittests in the template.

*******************************************************************************/

unittest
{
    new TripleDES(TripleDES.generateKey());
}
