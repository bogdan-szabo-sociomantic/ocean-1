/*******************************************************************************

    Provides a HMAC implementation

    copyright:      Copyright (C) dcrypt contributors 2008. All rights reserved.

    version:        Jan 2010: Initial release

    License:           MIT

    authors:        Thomas Dixon, Mathias L. Baumann

    Usage example:

    ---

        private import ocean.crypt.HMAC;
        private import tango.util.digest.Sha1;

        auto sha = new Sha1;
        auto hmac = new HMAC(sha);

        const secret_key = "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b";
        hmac.init(secret_key);

        const ubyte[] data = [23, 23, 23, 23]; // some data to encode
        hmac.update(data);

        auto encoded = hmac.digest;

        // To reuse the hmac object, init() must be called again.

    ---

*******************************************************************************/

module ocean.crypt.HMAC;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Exception;

private import ocean.crypt.misc.ByteConverter;

private import ocean.crypt.misc.Bitwise;

private import tango.util.digest.MerkleDamgard;

debug
{
    private import tango.util.digest.Sha1;
    private import ocean.util.log.Trace;
}



/*******************************************************************************

    Implementation of Keyed-Hash Message Authentication Code (HMAC)

    Conforms: RFC 2104
     References: http://www.faqs.org/rfcs/rfc2104.html

*******************************************************************************/

public class HMAC
{
    /***************************************************************************

        Hashing algorithm (passed to constructor).

    ***************************************************************************/

    private const MerkleDamgard hash;


    /***************************************************************************

        Internal buffers.

    ***************************************************************************/

    private ubyte[] ipad, opad, key;


    /***************************************************************************

        Flag set to true when the init() method is called. The update() method
        requires that the instance is initialized.

    ***************************************************************************/

    private bool initialized;


    /***************************************************************************

        Constructor. Creates a new instance of an HMAC object

        Params:
            hash = the hash algorithm to use (i.E. new Sha1(); )
            key = the key to initialize with

    ***************************************************************************/

    public this ( MerkleDamgard hash)
    {
        this.hash = hash;
        this.hash.reset();

        this.ipad = new ubyte[this.blockSize];
        this.opad = new ubyte[this.blockSize];
    }


    /***************************************************************************

        Initializes the HMAC object

        Params:
            k        = the key to initialize from
            buffer = buffer to use

    ***************************************************************************/

    public void init ( ubyte[] k, ubyte[] buffer )
    {
        this.hash.reset();

        if (k.length > this.blockSize)
        {
            this.hash.update(k);
            this.key = this.hash.binaryDigest(buffer)[0 .. this.hash.digestSize()];
        }
        else
        {
            this.key = k;
        }

        this.ipad[] = 0x36;
        this.opad[] = 0x5c;

        foreach (uint i, ubyte j; this.key)
        {
            this.ipad[i] ^= j;
            this.opad[i] ^= j;
        }

        this.reset();

        this.initialized = true;
    }


    /***************************************************************************

        Add more data to process

        Params:
            input = the data

        Throws:
            if the instance has not been initialized (with the init() method).

    ***************************************************************************/

    public void update ( ubyte[] input )
    {
        if (!this.initialized)
            throw new HMACException(this.name()~": HMAC not initialized.");

        this.hash.update(input);
    }


    /***************************************************************************

        Returns the name of the algorithm

        Returns:
            Returns the name of the algorithm

    ***************************************************************************/

    public char[] name()
    {
        return "HMAC-" ~ this.hash.toString;
    }


    /***************************************************************************

        Resets the state

    ***************************************************************************/

    public void reset()
    {
        this.hash.reset();
        this.hash.update(this.ipad);
    }


    /***************************************************************************

        Returns the blocksize

    ***************************************************************************/

    public uint blockSize()
    {
        return this.hash.blockSize;
    }


    /***************************************************************************

        Returns the size in bytes of the digest

    ***************************************************************************/

    public uint macSize()
    {
        return this.hash.digestSize;
    }


    /***************************************************************************

        Computes the digest and returns it

        Params:
            buffer = buffer to use

    ***************************************************************************/

    public ubyte[] digest ( ubyte[] buffer )
    {
        ubyte[] t = this.hash.binaryDigest(buffer)[0 .. this.hash.digestSize()];
        this.hash.update(this.opad);
        this.hash.update(t);

        if (buffer.length < t.length)
        {
            buffer = null;
        }
        else
        {
            buffer = buffer[t.length .. $];
        }

        ubyte[] r = this.hash.binaryDigest(buffer)[0 .. this.hash.digestSize()];

        this.reset();

        return r;
    }


    /***************************************************************************

        Computes the digest and returns it as hex

        Params:
            buffer = optional buffer to use

    ***************************************************************************/

    public char[] hexDigest ( ubyte[] buffer )
    {
        return ByteConverter.hexEncode(this.digest(buffer));
    }


    /***************************************************************************

        UnitTest

    ***************************************************************************/

    debug unittest
    {
        static char[][] test_keys = [
            "0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b",
            "4a656665", // Jefe?
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"~
            "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
        ];

        static char[][] test_inputs = [
            "4869205468657265",
            "7768617420646f2079612077616e7420666f72206e6f7468696e673f",
            "dd",
            "54657374205573696e67204c6172676572205468616e20426c6f63"~
            "6b2d53697a65204b6579202d2048617368204b6579204669727374"
        ];

        static int[] test_repeat = [
            1, 1, 50, 1
        ];

        static char[][] test_results = [
            "b617318655057264e28bc0b6fb378c8ef146be00",
            "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79",
            "125d7342b9ac11cd91a39af48aa17b4f63f175d3",
            "aa4ae5e15272d00e95705637ce8a3b55ed402112"
        ];

        ubyte[200] buffer;

        HMAC h = new HMAC(new Sha1());
        foreach (uint i, char[] k; test_keys)
        {
            h.init(ByteConverter.hexDecode(k), buffer);
            for (int j = 0; j < test_repeat[i]; j++)
                h.update(ByteConverter.hexDecode(test_inputs[i]));
            char[] mac = h.hexDigest(buffer);
            assert(mac == test_results[i],
                    h.name~": ("~mac~") != ("~test_results[i]~")");
        }
    }
}