/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        September 2013: Initial release

    author:         Stefan Brus

    Contains utility functions for working with unicode strings.

    Example usage:

    ---

        char[] utf = ...; // some UTF-8 character sequence

        // using the default unicode error handler
        size_t len1 = utf8Length(utf);

        // using a custom error handler
        // which takes the index of the string as a parameter
        size_t len2 = utf8Length(utf, (size_t i){ // error handling code...  });

    ---

*******************************************************************************/

module ocean.text.utf.UtfUtil;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.core.Exception: onUnicodeError;



/*******************************************************************************

    This array gives the length of a UTF-8 sequence indexed by the value
    of the leading byte. An FF (ubyte.max) represents an illegal starting value
    of a UTF-8 sequence.
    FF is used instead of 0 to avoid having loops hang.

*******************************************************************************/

private const ubyte[char.max + 1] utf8_stride =
[
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,ubyte.max,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,
    3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,
    4,4,4,4,4,4,4,4,5,5,5,5,6,6,ubyte.max,ubyte.max,
];


/*******************************************************************************

    Calculates the number of UTF8 code points in a UTF8-encoded string.
    Calls the standard unicode error handler on error,
    which throws a new UnicodeException.

    Params:
        str = The string to calculate the length of.

    Returns:
        The length of the given string.

    Throws:
        UnicodeException if an invalid UTF8 code unit is detected.

*******************************************************************************/

public size_t utf8Length ( char[] str )
{
    void error ( size_t i )
    {
        onUnicodeError("invalid UTF-8 sequence", i);
    }

    return utf8Length(str, &error);
}


/*******************************************************************************

    Calculates the number of UTF8 code points in a UTF8-encoded string.
    Calls error_dg if an invalid UTF8 code unit is detected,
    which may throw an exception to abort processing.

    Params:
        str = The string to calculate the length of.
        error_dg = The error delegate to call upon finding an invalid code unit.
            Takes a size_t parameter representing the index of the current
            code point in the string.

    Returns:
        The length of the given string.

*******************************************************************************/

public size_t utf8Length ( char[] str, void delegate ( size_t ) error_dg )
{
    size_t length;
    size_t i;
    size_t stride;

    for ( i = 0; i < str.length; i += stride )
    {
        // check how much we should increment the index
        // based on the size of the current UTF8 code point
        stride = utf8_stride[str[i]];

        if ( stride == ubyte.max )
        {
            error_dg(i);
        }

        length++;
    }

    if ( i > str.length )
    {
        assert(i >= stride, "i should be stride or greater");
        i -= stride;
        assert(i < str.length, "i - stride should be less than str.length");
        error_dg(i);
    }

    return length;
}

unittest
{
    assert(utf8Length(null) == 0,
        "the length of a null string should be 0");

    assert(utf8Length("") == 0,
        "the length of an empty string should be 0");

    assert(utf8Length("foo bar baz xyzzy") == 17,
        "the length of \"foo bar baz xyzzy\" should be 17");

    assert(utf8Length("ðäß ßøø+ ì$ æ ¢ööđ µøvi€ →→→") == 28,
        "the length of \"ðäß ßøø+ ì$ æ ¢ööđ µøvi€ →→→\" should be 28");

    // test if error delegate is called for an invalid string
    bool error_caught = false;
    const char[] error_str = "error in " ~ char.init ~ " the middle";
    utf8Length(error_str, ( size_t i ) { error_caught = true; });
    assert(error_caught,
        "the call to utf8Length should have caught an error");

    // test if error delegate is called for a valid string
    error_caught = false;
    const char[] valid_str = "There are no errors in this string!";
    utf8Length(valid_str, ( size_t i ) { error_caught = true; });
    assert(!error_caught,
        "the call to utf8Length should not have caught an error");
}
