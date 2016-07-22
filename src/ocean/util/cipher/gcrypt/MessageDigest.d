/*******************************************************************************

    libgcrypt message digest and HMAC utility classes.

    Be aware that not all versions of libcgrypt support all hash algorithms; the
    `MessageDigest` constructor will throw if the specified algorithm is not
    supported by the run-time version of libgcrypt. However, if the constructor
    does not throw, it is safe to assume it will never throw for the same set of
    parameters (except for the fatal situation that libgcrypt failed allocating
    memory).

    Requires linking with libgcrypt:
            -L-lgcrypt

    Copyright: Copyright (c) 2016 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.util.cipher.gcrypt.MessageDigest;

import ocean.transition;

class MessageDigest
{
    import ocean.util.cipher.gcrypt.c.md;
    import ocean.util.cipher.gcrypt.core.Gcrypt: GcryptException;

    /***************************************************************************

        libgcrypt message digest context object.

    ***************************************************************************/

    protected gcry_md_hd_t md;

    /***************************************************************************

        Constructor.

        Params:
            algorithm = the hash algorithm to use
            flags     = flags to `gcry_md_open()`

        Throws:
            `GcryptException` on error. There are two possible error causes:
              - The parameters are invalid or not supported by the libcrypt
                of the run-time enviromnent.
              - libgcrypt failed allocating memory.

    ***************************************************************************/

    public this ( gcry_md_algos algorithm, gcry_md_flags flags = cast(gcry_md_flags)0,
                  istring file = __FILE__, int line = __LINE__ )
    out
    {
        assert(this.md !is null);
    }
    body
    {
        // `gcry_md_open` sets `this.md = null` on failure.
        throwIfGcryptError(gcry_md_open(&this.md, algorithm, flags), file, line);
    }

    /***************************************************************************

        Destructor; closes the object opened by the constructor.

    ***************************************************************************/

    ~this ( )
    {
        // `gcry_md_close` ignores `null` so it is safe to call it after
        // `gcry_md_open()` failed and made the constructor throw.
        gcry_md_close(this.md);
        this.md = null;
    }

    /***************************************************************************

        Calculates the hash a.k.a. message digest from the input data.

        Discards the result of a previous hash calculation, invalidating and
        overwriting a previously returned result.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            input_data = data to hash; the elements will be concatenated

        Returns:
            the resuting hash.

    ***************************************************************************/

    public ubyte[] hash ( Const!(void)[][] input_data ... )
    {
        gcry_md_reset(this.md);
        return this.hash_(input_data);
    }

    /***************************************************************************

        Calculates the hash a.k.a. message digest from the input data.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            input_data = data to hash; the elements will be concatenated

        Returns:
            the resuting hash.

    ***************************************************************************/

    protected ubyte[] hash_ ( Const!(void)[][] input_data )
    {
        foreach (chunk; input_data)
        {
            gcry_md_write(this.md, chunk.ptr, chunk.length);
        }

        return gcry_md_read_slice(this.md);
    }

    /***************************************************************************

        Throws `new GcryptException` if `error` is not 0.

        Params:
            error = non-zero error code or 0

        Throws:
            GcryptException if `error` is not 0.

    ***************************************************************************/

    protected static void throwIfGcryptError ( gcry_error_t error,
                                               istring file = __FILE__,
                                               int line = __LINE__ )
    {
        if (error)
        {
            (new GcryptException).throwIfGcryptError(error, file, line);
        }
    }
}

/******************************************************************************/

class HMAC: MessageDigest
{
    /***************************************************************************

        Constructor.

        Params:
            algorithm = the hash algorithm to use
            flags     = flags to `gcry_md_open()`; `flags.GCRY_MD_FLAG_HMAC` is
                        added automatically

        Throws:
            `GcryptException` on error, including the case that the run-time
            libgcrypt doesn't support `algorithm` for HMAC calculation.

    ***************************************************************************/

    public this ( gcry_md_algos algorithm, gcry_md_flags flags = cast(gcry_md_flags)0,
                  istring file = __FILE__, int line = __LINE__ )
    {
        super(algorithm, flags | flags.GCRY_MD_FLAG_HMAC, file, line);
    }

    /***************************************************************************

        Calculates the HMAC from the authentication key and the input data.

        Discards the result of a previous hash calculation, invalidating and
        overwriting a previously returned result.

        An error can be caused only by the parameters passed to the constructor.
        If this method does not throw, it is safe to assume it will never throw
        for the same set of constructor parameters.

        `key_and_input_data[0]` is expected to be the authentication key. If
        `key_and_input_data.length == 0` then an empty key and no data are used.

        The length of the returned hash is the return value of
        `gcry_md_get_algo_dlen(algorithm)` for the algorithm passed to the
        constructor of this class.

        Params:
            hmac_and_input_data = the first element is the HMAC key, the
                following the data to hash, which will be concatenated

        Returns:
            the resuting HMAC.

        Throws:
            `GcryptException` on error.

    ***************************************************************************/

    override public ubyte[] hash ( Const!(void)[][] key_and_input_data ... )
    {
        gcry_md_reset(this.md);

        if (key_and_input_data.length)
        {
            throwIfGcryptError(gcry_md_setkey(this.md,
                key_and_input_data[0].ptr, key_and_input_data[0].length
            ));
            return this.hash_(key_and_input_data[1 .. $]);
        }
        else
        {
            throwIfGcryptError(gcry_md_setkey(this.md, null, 0));
            return this.hash_(null);
        }
    }
}

/******************************************************************************/

version ( UnitTest )
{
    import ocean.core.Test;
}

unittest
{
    // http://csrc.nist.gov/groups/ST/toolkit/documents/Examples/SHA224.pdf
    static Immut!(ubyte)[] sha224_hash = [
        0x75, 0x38, 0x8B, 0x16, 0x51, 0x27, 0x76,
        0xCC, 0x5D, 0xBA, 0x5D, 0xA1, 0xFD, 0x89,
        0x01, 0x50, 0xB0, 0xC6, 0x45, 0x5C, 0xB4,
        0xF5, 0x8B, 0x19, 0x52, 0x52, 0x25, 0x25
    ];

    scope md = new MessageDigest(MessageDigest.gcry_md_algos.GCRY_MD_SHA224);
    test!("==")(
        md.hash(
            "abcdbcdec", "defdefgefghfghig", "hi",
            "jhijkijkljklmklmnlmnomno", "pnopq"
        ),
        sha224_hash
    );

    // https://tools.ietf.org/html/rfc4231#section-4.2
    static Immut!(ubyte)[] sha224_hmac = [
        0x89, 0x6f, 0xb1, 0x12, 0x8a, 0xbb, 0xdf,
        0x19, 0x68, 0x32, 0x10, 0x7c, 0xd4, 0x9d,
        0xf3, 0x3f, 0x47, 0xb4, 0xb1, 0x16, 0x99,
        0x12, 0xba, 0x4f, 0x53, 0x68, 0x4b, 0x22
    ];

    Immut!(ubyte)[20] key = 0x0b;
    scope hmacgen = new HMAC(HMAC.gcry_md_algos.GCRY_MD_SHA224);
    test!("==")(hmacgen.hash(key, "Hi", " ", "There"), sha224_hmac);
}
