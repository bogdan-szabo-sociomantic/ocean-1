/*******************************************************************************

    Wrapper for libgcrypt with algorithm Twofish and mode CFB

    Requires linking with libgcrypt:
            -L-lgcrypt

    See_Also:
        https://en.wikipedia.org/wiki/Twofish
        https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation

    Copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.Twofish;

import ocean.util.cipher.gcrypt.core.Gcrypt;
import tango.transition;


/*******************************************************************************

    Gcrypt with Twofish with mode CFB.

    See usage example in unittest below.

*******************************************************************************/

public alias Gcrypt!(Algorithm.GCRY_CIPHER_TWOFISH, Mode.GCRY_CIPHER_MODE_CFB) Twofish;

version ( UnitTest )
{
    import tango.core.Test;
}

/// Usage example
unittest
{
    // Twofish requires a key of length 32 bytes
    auto key = cast(Immut!(ubyte)[])"a key of 32 bytesa key of32bytes";
    // Twofish requires an initialisation vector of length 16 bytes.
    auto iv = cast(Immut!(ubyte)[])"a iv of 16 bytes";

    istring text = "This is a text we are going to encrypt";
    mstring encrypted_text, decrypted_text;

    // Create the class
    auto two = new Twofish(key);

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
    new Twofish(Twofish.generateKey());
}
