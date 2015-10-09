/*******************************************************************************

    Wrapper for libgcrypt with algorithm Twofish and mode CFB

    Requires linking with libgcrypt:
            -L-lgcrypt

    This module has support for the algorithm Twofish but it could be easily
    split into one generic Gcrypt class and one (or more) derived classes for
    the specific algorithms. But since this is what's needed at the moment it's
    more important to have an easy interface.

    See_Also:

    Manual:
        https://gnupg.org/documentation/manuals/gcrypt/index.html

    Copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.Twofish;

import ocean.core.Exception;
import ocean.util.cipher.gcrypt.c.gcrypt;

import tango.stdc.stringz;
import tango.transition;

/*******************************************************************************

    Gcrypt with Twofish with mode CFB.

    https://en.wikipedia.org/wiki/Twofish
    https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation

    See unittest for usage example.

*******************************************************************************/

public class Twofish
{
    /***************************************************************************

        Reusable exception class

    ***************************************************************************/

    public static class GcryptException : Exception
    {
        /***********************************************************************

            Mixin the reusable exception parts

        ***********************************************************************/

        mixin ReusableExceptionImplementation!();

        /***********************************************************************

            Throw if variable error indicates an error. The exception message is
            set to contain the error from libgcrypt.

            Params:
                error = error code from gcrypt
                file = file from which this exception can be thrown
                line = line from which this exception can be thrown

            Throws:
                this if error != 0

        ***********************************************************************/

        public void throwIfGcryptError ( gcry_error_t error,
                                         istring file = __FILE__,
                                         int line = __LINE__  )
        {
            if ( error )
            {
                this.set(`Error: "`, file, line)
                    .append(fromStringz(gcry_strerror(error)))
                    .append(`" Source: "`)
                    .append(fromStringz(gcry_strsource(error)))
                    .append(`"`);
                throw this;
            }
        }

        /***********************************************************************

            Throw if iv_length != block_size, with exception message explaining
            the issue.

            Params:
                error = error code from gcrypt
                file = file from which this exception can be thrown
                line = line from which this exception can be thrown

            Throws:
                this if iv_length != block_size

        ***********************************************************************/

        public void throwIfIvLenMismatch ( size_t iv_length, size_t block_size,
                                           istring file = __FILE__,
                                           int line = __LINE__  )
        {
            if ( iv_length != block_size )
            {
                this.set(`IV length is: `, file, line)
                    .append(iv_length)
                    .append(` but needs to be `)
                    .append(block_size);
                throw this;
            }
        }
    }


    /***************************************************************************

        Alias for the libgcrypt algorithm

    ***************************************************************************/

    protected alias gcry_cipher_algos Algorithm;


    /***************************************************************************

        Alias for the libgcrypt modes

    ***************************************************************************/

    protected alias gcry_cipher_modes Modes;


    /***************************************************************************

        Gcrypt handler

    ***************************************************************************/

    protected gcry_cipher_hd_t handler;


    /***************************************************************************

        Reusable exception

    ***************************************************************************/

    protected GcryptException exception;


    /***************************************************************************

        Constructs the class and sets gcrypt to use the Twofish with mode CFB
        and the key.

        Params:
            key = the key to use.

        Throws:
            A GcryptException if gcrypt fails to open or the key fails to be set

    ***************************************************************************/

    public this (in void[] key )
    {
        this.exception = new GcryptException();

        with ( gcry_ctl_cmds )
        {
            // We don't need secure memory
            this.throwIfError(gcry_control(GCRYCTL_DISABLE_SECMEM, 0));
            this.throwIfError(gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0));
        }

        // open gcypt with Twofish with mode CFB
        this.throwIfError(gcry_cipher_open(&this.handler,
                                           Algorithm.GCRY_CIPHER_TWOFISH,
                                           Modes.GCRY_CIPHER_MODE_CFB, 0));

        // Set the key, since we don't call the gcrypts reset function we only
        // need to do this once.
        this.setKey(key);
    }


    /***************************************************************************

        Destructor which close gcrypt

    ***************************************************************************/

    public ~this ( )
    {
        gcry_cipher_close(this.handler);
        this.handler = null;
    }


    /***************************************************************************

        Encrypt the content of buffer in place.

        Params:
            buffer = the content to be encrypted in place.
            iv = the initialisation vector to use

        Throws:
            if buffer is null, the initialisation vector does not have the
            correct length or can't be set or the encryption fails

    ***************************************************************************/

    public void encrypt ( mstring buffer, void[] iv )
    {
        this.exception.enforce(buffer.length, "buffer can't be null");

        // The iv needs always to be set before encrypt is called
        this.setInitVector(iv);

        this.throwIfError(gcry_cipher_encrypt(this.handler, buffer.ptr,
                                              buffer.length, null, 0));
    }


    /***************************************************************************

        Decrypt the content of buffer in place.

        Params:
            buffer = the content to be decrypted in place.
            iv = the initialisation vector to use

        Throws:
            if buffer is null, the initialisation vector does not have the
            correct length or can't be set or the decryption fails

    ***************************************************************************/

    public void decrypt ( mstring buffer, void[] iv )
    {
        this.exception.enforce(buffer.length, "buffer can't be null");

        // The iv needs always to be set before decrypt is called
        this.setInitVector(iv);

        this.throwIfError(gcry_cipher_decrypt(this.handler, buffer.ptr,
                                              buffer.length, null, 0));
    }


    /***************************************************************************

        Set the key to use.

        Params:
            key = the encryption key

        Throws:
            A GcryptException if the key failed to be set

    ***************************************************************************/

    protected void setKey ( in void[] key )
    {
        this.throwIfError(gcry_cipher_setkey(this.handler, key.ptr, key.length));
    }


    /***************************************************************************

        Set the initialization vector to use.

        Params:
            iv = the initialization vector

        Throws:
            A GcryptException if the initialization vector failed to be set

    ***************************************************************************/

    protected void setInitVector ( in void[] iv )
    {
        size_t block_size =
                     gcry_cipher_get_algo_blklen(Algorithm.GCRY_CIPHER_TWOFISH);

        // This shouldn't happen since the algorithm has already been properly set
        assert(block_size != 0);

        // The IV should have the same length as the block size
        this.exception.throwIfIvLenMismatch(iv.length, block_size);

        this.throwIfError(gcry_cipher_setiv(this.handler, iv.ptr, iv.length));
    }


    /***************************************************************************

        Helper method to throw if the return value of a libgcrypt function
        indicates an error.

        Params:
            ret  = the return value of a libgcrypt function
            file = file from which this exception can be thrown
            line = line from which this exception can be thrown

        Throws:
            if ret indicates an error

    ***************************************************************************/

    protected void throwIfError ( gcry_error_t error, istring file = __FILE__,
                                int line = __LINE__  )
    {
        this.exception.throwIfGcryptError(error, file, line);
    }
}



/// Usage example
unittest
{
    // Twofish requires a key of length 32 bytes
    ubyte[] key = cast(ubyte[])"a key of 32 bytesa key of32bytes";
    // Twofish requires an initialisation vector of length 16 bytes.
    ubyte[] iv = cast(ubyte[])"a iv of 16 bytes";

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

version ( UnitTest )
{
    import tango.core.Test;
}

unittest
{
    ubyte[] key = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                   17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31];

    ubyte[] iv =  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];

    istring text = "apabepacepa";
    mstring enc_buf, dec_buf;

    enc_buf ~= text;

    // Key to short
    testThrown!(Twofish.GcryptException)(new Twofish(key[0 .. $-1]));
    testThrown!(Twofish.GcryptException)(new Twofish(key ~ cast(ubyte)32));

    auto two = new Twofish(key);

    testThrown!(Twofish.GcryptException)(two.encrypt(enc_buf, iv[0 .. $-1]));
    testThrown!(Twofish.GcryptException)(two.encrypt(enc_buf, iv ~ cast(ubyte)16));

    // encrypt enc_buf in place
    two.encrypt(enc_buf, iv);

    test!("!=")(enc_buf, text);

    dec_buf ~= enc_buf;

    // encrypt dec_buf in place
    two.decrypt(dec_buf, iv);

    test!("==")(dec_buf, text);
}
