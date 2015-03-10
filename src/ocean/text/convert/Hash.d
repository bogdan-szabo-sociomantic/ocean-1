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

import Integer = ocean.text.convert.Integer;

import ocean.core.TypeConvert;


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

public bool toHashT ( char[] str, out hash_t hash,
    bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( char[] str )
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
        assert(!toHashT("", hash));

        // just radix
        assert(!toHashT("0x", hash, true));

        // non-hex
        assert(!toHashT("zzz", hash));

        // integer overflow
        assert(!toHashT("12345678123456789", hash));

        // simple hash
        toHashT("12345678", hash);
        assert(hash == 0x12345678);

        // hash with radix, disallowed
        assert(!toHashT("0x12345678", hash));

        // hash with radix, allowed
        toHashT("0x12345678", hash, true);
        assert(hash == 0x12345678);
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

public bool hashDigestToHashT ( char[] str, out hash_t hash,
    bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( char[] str )
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
        assert(!hashDigestToHashT("", hash));

        // just radix
        assert(!hashDigestToHashT("0x", hash, true));

        // non-hex
        assert(!hashDigestToHashT("zzz", hash));

        // too short
        assert(!hashDigestToHashT("123456781234567", hash));

        // too short, with radix
        assert(!hashDigestToHashT("0x" ~ "123456781234567", hash, true));

        // too long
        assert(!hashDigestToHashT("12345678123456789", hash));

        // too long, with radix
        assert(!hashDigestToHashT("0x12345678123456789", hash, true));

        // just right
        hashDigestToHashT("1234567812345678", hash);
        assert(hash == 0x1234567812345678);

        // just right with radix, disallowed
        assert(!hashDigestToHashT("0x1234567812345678", hash));

        // just right with radix, allowed
        hashDigestToHashT("0x1234567812345678", hash, true);
        assert(hash == 0x1234567812345678);
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

public char[] toHashDigest ( hash_t hash, ref char[] str )
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
    char[] str;

    static if ( HashDigits == 16 )
    {
        assert(toHashDigest(hash_t.min, str) == "0000000000000000");
        assert(toHashDigest(hash_t.max, str) == "ffffffffffffffff");
    }
    else
    {
        assert(toHashDigest(hash_t.min, str) == "00000000");
        assert(toHashDigest(hash_t.max, str) == "ffffffff");
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

public bool isHex ( char[] str, bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( char[] str )
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
    assert(isHex(""));

    // radix only, allowed
    assert(isHex("0x", true));

    // radix only, disallowed
    assert(!isHex("0x"));

    // non-hex
    assert(!isHex("zzz"));

    // simple hex
    assert(isHex("1234567890abcdef"));

    // simple hex, upper case
    assert(isHex("1234567890ABCDEF"));

    // simple hex with radix, allowed
    assert(isHex("0x1234567890abcdef", true));

    // simple hex with radix, disallowed
    assert(!isHex("0x1234567890abcdef"));
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
    bool contains ( char[] str, char c )
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

    char[] good = "0123456789abcdefABCDEF";

    for ( int i = char.min; i <= char.max; i++ )
    {
        // can't use char for i because of expected overflow
        auto c = castFrom!(int).to!(char)(i);
        if ( good.contains(c) )
        {
            assert(isHex(c));
        }
        else
        {
            assert(!isHex(c));
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

public bool isHashDigest ( char[] str, bool allow_radix = false )
{
    return handleRadix(str, allow_radix,
        ( char[] str )
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
        assert(!isHashDigest(""));

        // radix only, allowed
        assert(!isHashDigest("0x", true));

        // radix only, disallowed
        assert(!isHashDigest("0x"));

        // too short
        assert(!isHashDigest("123456781234567"));

        // too short, with radix
        assert(!isHashDigest("0x" ~ "123456781234567", true));

        // too long
        assert(!isHashDigest("12345678123456789"));

        // too long, with radix
        assert(!isHashDigest("0x" ~ "12345678123456789", true));

        // just right
        assert(isHashDigest("1234567812345678"));

        // just right, with radix
        assert(isHashDigest("0x1234567812345678", true));
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

public char[] hexToLower ( char[] str )
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
    assert(hexToLower("") == "");

    // numbers only
    assert(hexToLower("123456678".dup) == "123456678");

    // lower case letters
    assert(hexToLower("abcdef".dup) == "abcdef");

    // upper case letters
    assert(hexToLower("ABCDEF".dup) == "abcdef");

    // non-hex letters, lower case
    assert(hexToLower("uvwxyz".dup) == "uvwxyz");

    // non-hex letters, upper case
    assert(hexToLower("UVWXYZ".dup) == "UVWXYZ");

    // mixed
    assert(hexToLower("12345678abcdefABCDEFUVWXYZ".dup) == "12345678abcdefabcdefUVWXYZ");

    // check that string is modified in-place
    char[] str = "ABCDEF".dup;
    auto converted = hexToLower(str);
    assert(converted.ptr == str.ptr);
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

private bool handleRadix ( char[] str, bool allow_radix,
    bool delegate ( char[] ) process )
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

