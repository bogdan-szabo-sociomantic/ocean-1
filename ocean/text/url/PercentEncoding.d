/*******************************************************************************

    Functions to convert non-ascii characters to percent encoded form, and vice
    versa.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        September 2011: Initial release

    authors:        Gavin Norman

    Only non-ascii and non-reserved characters are converted. Reserved
    characters are by default:

        !$&'()*+,;=:@/?

    (an alternative list can be passed to the encode() function, if required).

    See:

    ---

        http://en.wikipedia.org/wiki/Percent-encoding

    ---

    Link with:

    ---

        -L-lgblib-2.0

    ---

    Usage example:

    ---

        import PercentEncoding = ocean.text.url.PercentEncoding;

        char[] url = "http://www.stepstone.de/upload_DE/logo/G/logoGebühreneinzugszentrale_8974DE.gif".dup;
        char[] encoded;
        char[] working;

        PercentEncoding.encode(url, encoded, working);

        // 'encoded' now equals:
        // "http://www.stepstone.de/upload_DE/logo/G/logoGeb%C3%BChreneinzugszentrale_8974DE.gif"

    ---

    TODO: at present these functions are wrappers around the equivalent glib
    functions, which have the desired behaviour. (The methods in tango.net.Uri
    do *not* have the desired behaviour -- it ruthlessly encodes every character
    in the string, including ascii & reserved characters!) It may be desirable
    at some point to write a pure D implementation of these functions, so as to:

        1. remove the dependancy on linking with the glib library
        2. avoid the string allocation & free which occurs with each call

*******************************************************************************/

module ocean.text.url.PercentEncoding;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array;

private import tango.stdc.string : strlen;

private import tango.stdc.stdlib : free;



/*******************************************************************************

    C functions

*******************************************************************************/

extern ( C )
{
    char* g_uri_escape_string ( char* unescaped, char* reserved_chars_allowed, bool allow_utf8 );

    char* g_uri_unescape_string ( char* escaped_string, char* illegal_characters );
}



/*******************************************************************************

    Percent encodes all non-ascii characters in the passed string which do also
    not appear in the dont_encode list. The encoded string is written to the dst
    parameter. The source string is not modified.

    The working buffer is used to avoid having to modify the src and dont_encode
    strings, which need to be null-terminated for use with the C function.

    Params:
        src = string to encode
        dst = receives encoded string
        working = working buffer
        dont_encode = list of characters to *not* encode (defaults to uri
            reserved characters list)

    Returns:
        encoded string (slice to dst)

*******************************************************************************/

public char[] encode ( char[] src, ref char[] dst, ref char[] working, char[] dont_encode = "!$&'()*+,;=:@/?" )
{
    working.concat(src, "\0");
    auto original = working;

    working.append(dont_encode, "\0");
    auto allowed = working[original.length + 1 .. $];

    auto encoded = g_uri_escape_string(original.ptr, allowed.ptr, false);
    scope ( exit ) free(encoded);

    dst.copy(encoded[0..strlen(encoded)]);

    return dst;
}


/*******************************************************************************

    Decodes any percent encoded characters in the passed string. The decoded
    string is written to the dst parameter. The source string is not modified.

    The working buffer is used to avoid having to modify the src string, which
    needs to be null-terminated for use with the C function.

    Params:
        src = string to decode
        dst = receives decoded string
        working = working buffer
    
    Returns:
        decoded string (slice to dst)

*******************************************************************************/

public char[] decode ( char[] src, ref char[] dst, ref char[] working )
{
    working.concat(src, "\0");

    auto decoded = g_uri_unescape_string(working.ptr, null);
    scope ( exit ) free(decoded);

    dst.copy(decoded[0..strlen(decoded)]);

    return dst;
}

