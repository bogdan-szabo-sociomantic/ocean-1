/*******************************************************************************

    Copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    Version:        2013-09-12: Initial release

    Authors:        Gavin Norman

    Utility functions for converting hash_t <-> hexadecimal strings.

    A few different types of data are handled:
        * Hex strings: strings of variable length containing valid hexadecimal
          digits (case insensitive), optionally prepended by the hex radix
          specifier ("0x")
        * Hash digests: hex strings of exactly hash_t.sizeof * 2 digits
        * hash_t

*******************************************************************************/

module ocean.text.convert.Hash;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;

import Integer = ocean.text.convert.Integer;

import ocean.core.TypeConvert;

version (UnitTest)
{
    import ocean.core.Test;
}


/*******************************************************************************

    Constant defining the number of hexadecimal digits needed to represent a
    hash_t.

*******************************************************************************/

public const HashDigits = hash_t.sizeof * 2;


/*******************************************************************************

    Converts from a hex string to a hash_t.

    Params:
        str = string to convert
        hash = output value to receive hex value, only set if conversion
            succeeds
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if the conversion succeeded

*******************************************************************************/

public bool toHashT ( cstring str, out hash_t hash,
    bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( cstring str )
        {
            return Integer.toUlong(str, hash, 16);
        });
}

unittest
{
    static if ( HashDigits == 16 )
    {
        hash_t hash;

        // empty string
        test!("==")(toHashT("", hash), false);

        // just radix
        test!("==")(toHashT("0x", hash, true), false);

        // non-hex
        test!("==")(toHashT("zzz", hash), false);

        // integer overflow
        test!("==")(toHashT("12345678123456789", hash), false);

        // simple hash
        toHashT("12345678", hash);
        test!("==")(hash, 0x12345678);

        // hash with radix, disallowed
        test!("==")(toHashT("0x12345678", hash), false);

        // hash with radix, allowed
        toHashT("0x12345678", hash, true);
        test!("==")(hash, 0x12345678);
    }
    else
    {
        pragma(msg, "Warning: ocean.text.convert.Hash.toHashT unittest not run in 32-bit");
    }
}


/*******************************************************************************

    Converts from a hash digest (exactly HashDigits digits) to a hash_t.

    Params:
        str = string to convert
        hash = output value to receive hex value, only set if conversion
            succeeds
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if the conversion succeeded

*******************************************************************************/

public bool hashDigestToHashT ( cstring str, out hash_t hash,
    bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( cstring str )
        {
            if ( str.length != HashDigits )
            {
                return false;
            }

            return Integer.toUlong(str, hash, 16);
        });
}

unittest
{
    static if ( HashDigits == 16 )
    {
        hash_t hash;

        // empty string
        test!("==")(hashDigestToHashT("", hash), false);

        // just radix
        test!("==")(hashDigestToHashT("0x", hash, true), false);

        // non-hex
        test!("==")(hashDigestToHashT("zzz", hash), false);

        // too short
        test!("==")(hashDigestToHashT("123456781234567", hash), false);

        // too short, with radix
        test!("==")(hashDigestToHashT("0x" ~ "123456781234567", hash, true), false);

        // too long
        test!("==")(hashDigestToHashT("12345678123456789", hash), false);

        // too long, with radix
        test!("==")(hashDigestToHashT("0x12345678123456789", hash, true), false);

        // just right
        hashDigestToHashT("1234567812345678", hash);
        test!("==")(hash, 0x1234567812345678);

        // just right with radix, disallowed
        test!("==")(hashDigestToHashT("0x1234567812345678", hash), false);

        // just right with radix, allowed
        hashDigestToHashT("0x1234567812345678", hash, true);
        test!("==")(hash, 0x1234567812345678);
    }
    else
    {
        pragma(msg, "Warning: ocean.text.convert.Hash.hashDigestToHashT unittest not run in 32-bit");
    }
}


/*******************************************************************************

    Creates a hash digest string from a hash_t.

    Params:
        hash = hash_t value to render to string
        str = destination string; length will be set to HashDigits

    Returns:
        string containing the hash digest

*******************************************************************************/

public mstring toHashDigest ( hash_t hash, ref mstring str )
{
    str.length = HashDigits;
    foreach_reverse ( ref c; str )
    {
        c = "0123456789abcdef"[hash & 0xF];
        hash >>= 4;
    }
    return str;
}

unittest
{
    mstring str;

    static if ( HashDigits == 16 )
    {
        test!("==")(toHashDigest(hash_t.min, str), "0000000000000000");
        test!("==")(toHashDigest(hash_t.max, str), "ffffffffffffffff");
    }
    else
    {
        test!("==")(toHashDigest(hash_t.min, str), "00000000");
        test!("==")(toHashDigest(hash_t.max, str), "ffffffff");
    }
}


/*******************************************************************************

    Checks whether str is a hex string (contains only valid hex digits),
    optionally with radix specifier ("0x").

    Params:
        str = string to check
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if str is a hex string

*******************************************************************************/

public bool isHex ( cstring str, bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( cstring str )
        {
            foreach ( c; str )
            {
                if ( !isHex(c) )
                {
                    return false;
                }
            }
            return true;
        });
}

unittest
{
    // empty string
    test!("==")(isHex(""), true);

    // radix only, allowed
    test!("==")(isHex("0x", true), true);

    // radix only, disallowed
    test!("==")(isHex("0x"), false);

    // non-hex
    test!("==")(isHex("zzz"), false);

    // simple hex
    test!("==")(isHex("1234567890abcdef"), true);

    // simple hex, upper case
    test!("==")(isHex("1234567890ABCDEF"), true);

    // simple hex with radix, allowed
    test!("==")(isHex("0x1234567890abcdef", true), true);

    // simple hex with radix, disallowed
    test!("==")(isHex("0x1234567890abcdef"), false);
}


/*******************************************************************************

    Checks whether a character is a valid hexadecimal digit.

    Params:
        c = character to check

    Returns:
        true if the character is a valid hex digit, false otherwise

*******************************************************************************/

public bool isHex ( char c )
{
    return (c >= '0' && c <= '9')
        || (c >= 'a' && c <= 'f')
        || (c >= 'A' && c <= 'F');
}

unittest
{
    bool contains ( cstring str, char c )
    {
        foreach ( cc; str )
        {
            if ( cc == c )
            {
                return true;
            }
        }
        return false;
    }

    istring good = "0123456789abcdefABCDEF";

    for ( int i = char.min; i <= char.max; i++ )
    {
        // can't use char for i because of expected overflow
        auto c = castFrom!(int).to!(char)(i);
        if ( contains(good, c) )
        {
            test!("==")(isHex(c), true);
        }
        else
        {
            test!("==")(!isHex(c), true);
        }
    }
}


/*******************************************************************************

    Checks whether str is a hash digest.

    Params:
        str = string to check
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str

    Returns:
        true if str is a hash digest

*******************************************************************************/

public bool isHashDigest ( cstring str, bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( cstring str )
        {
            if ( str.length != HashDigits )
            {
                return false;
            }

            return isHex(str);
        });
}

unittest
{
    static if ( HashDigits == 16 )
    {
        // empty string
        test!("==")(isHashDigest(""), false);

        // radix only, allowed
        test!("==")(isHashDigest("0x", true), false);

        // radix only, disallowed
        test!("==")(isHashDigest("0x"), false);

        // too short
        test!("==")(isHashDigest("123456781234567"), false);

        // too short, with radix
        test!("==")(isHashDigest("0x" ~ "123456781234567", true), false);

        // too long
        test!("==")(isHashDigest("12345678123456789"), false);

        // too long, with radix
        test!("==")(isHashDigest("0x" ~ "12345678123456789", true), false);

        // just right
        test!("==")(isHashDigest("1234567812345678"), true);

        // just right, with radix
        test!("==")(isHashDigest("0x1234567812345678", true), true);
    }
    else
    {
        pragma(msg, "Warning: ocean.text.convert.Hash.isHashDigest unittest not run in 32-bit");
    }
}


/*******************************************************************************

    Converts any characters in the range A..F in a hex string to lower case
    (a..f).

    Params:
        str = string to convert

    Returns:
        converted string (characters modified in-place)

*******************************************************************************/

public mstring hexToLower ( mstring str )
{
    const to_lower = ('A' - 'a');
    foreach ( ref c; str )
    {
        if ( c >= 'A' && c <= 'F' )
        {
            c -= to_lower;
        }
    }

    return str;
}

unittest
{
    // empty string
    test!("==")(hexToLower(null), "");

    // numbers only
    test!("==")(hexToLower("123456678".dup), "123456678");

    // lower case letters
    test!("==")(hexToLower("abcdef".dup), "abcdef");

    // upper case letters
    test!("==")(hexToLower("ABCDEF".dup), "abcdef");

    // non-hex letters, lower case
    test!("==")(hexToLower("uvwxyz".dup), "uvwxyz");

    // non-hex letters, upper case
    test!("==")(hexToLower("UVWXYZ".dup), "UVWXYZ");

    // mixed
    test!("==")(hexToLower("12345678abcdefABCDEFUVWXYZ".dup), "12345678abcdefabcdefUVWXYZ");

    // check that string is modified in-place
    mstring str = "ABCDEF".dup;
    auto converted = hexToLower(str);
    test!("==")(converted.ptr, str.ptr);
}


/*******************************************************************************

    Checks whether the radix in str (if present) matches the allow_radix flag,
    and passes the radix-stripped string to the provided delegate.

    Params:
        str = string to convert
        allow_radix = if true, the radix specified "0x" is allowed at the start
            of str
        process = process to perform on string if radix is as expected

    Returns:
        if str starts with "0x" and allow_radix is false, returns false
        otherwise, passes on the return value of the process delegate

*******************************************************************************/

private bool handleRadix ( cstring str, bool allow_radix,
    bool delegate ( cstring ) process )
{
    if ( str.length >= 2 && str[0..2] == "0x" )
    {
        if ( !allow_radix )
        {
            return false;
        }
        else
        {
            str = str[2..$];
        }
    }

    return process(str);
}

