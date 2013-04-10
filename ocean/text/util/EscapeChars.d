/******************************************************************************

    Escapes characters in a string, that is, prepends '\' to special characters.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        December 2010: Initial release

    author:         David Eckardt

 ******************************************************************************/

module ocean.text.util.EscapeChars;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.core.Array: concat;

private import tango.stdc.string: strcspn, memmove, memcpy, memchr, strlen;

/******************************************************************************/

struct EscapeChars
{
    /**************************************************************************

        Tokens string consisting of the default special characters to escape

     **************************************************************************/

    const Tokens = `"'\`;

    /**************************************************************************

        List of special characters to escape

     **************************************************************************/

    private char[] tokens;

    /**************************************************************************

        List of occurrences

     **************************************************************************/

    private size_t[] occurrences;

    /**************************************************************************

        Escapes each occurrence of an element of Tokens in str by inserting
        the escape pattern escape into str before the occurrence.

        Params:
            str    = string with characters to escape; changed in-place
            escape = escape pattern to prepend to each token occurrence
            tokens = List of special characters to escape; empty string
                     indicates to do nothing. '\0' tokens are not allowed.

        Returns:
            resulting string

     **************************************************************************/

    public char[] opCall ( ref char[] str, char[] escape = `\`,
                           char[] tokens = this.Tokens )
    {
        if (tokens.length)
        {
            this.copyTokens(tokens);

            str ~= '\0';                                                        // append a 0 to the end, as it is stripped in the scope(exit)

            scope (exit)
            {
                assert (str.length);
                assert (!str[$ - 1]);
                str.length = str.length - 1;
            }

            size_t end = str.length - 1;

            this.occurrences.length = 0;

            for (size_t pos = strcspn(str.ptr, tokens.ptr); pos < end;)
            {
                this.occurrences ~= pos;

                pos += strcspn(str.ptr + ++pos, tokens.ptr);
            }

            str.length = str.length + (this.occurrences.length * escape.length);

            str[$ - 1] = '\0';                                                  // append a 0 to the end, as it is stripped in the scope(exit)

            foreach_reverse (i, occurrence; this.occurrences)
            {
                char* src = str.ptr + occurrence;
                char* dst = src + ((i + 1) * escape.length);

                memmove(dst, src, end - occurrence);
                memcpy(dst - escape.length, escape.ptr, escape.length);

                end = occurrence;
            }
        }

        return str;
    }

    /**************************************************************************

        Copies tok to this.tokens and appends a NUL terminator.

        Params:
            tokens = list of character tokens

     **************************************************************************/

    private void copyTokens ( char[] tokens )
    in
    {
        assert (tokens);
        assert (!memchr(tokens.ptr, '\0', tokens.length),
                typeof (*this).stringof ~ ": NUL characters not allowed in tokens");
    }
    out
    {
        assert (this.tokens.length);
        assert (!this.tokens[$ - 1]);
        assert (this.tokens.length - 1 == strlen(this.tokens.ptr));
    }
    body
    {
        this.tokens.concat(tokens, "\0");
    }
}
