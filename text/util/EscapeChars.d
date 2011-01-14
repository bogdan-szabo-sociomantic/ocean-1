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

private import tango.stdc.string: strcspn, memmove;

/******************************************************************************/

struct EscapeChars
{
    /**************************************************************************

        Tokens string consisting of the special characters to escape
    
     **************************************************************************/

    const Tokens = "\"'\\";
    
    /**************************************************************************

        List of occurrences
    
     **************************************************************************/
    
    private size_t[] occurrences;
    
    /**************************************************************************

        Escapes each occurrence of an element of Tokens in str by inserting
        '\' into str before the occurrence.
        
        Params:
            str = string with characters to escape; changed in-place
            
        Returns:
            resulting string
    
     **************************************************************************/

    public char[] opCall ( ref char[] str, char[] escape = `\` )
    {
        char* occurrence_ptr, src, dst;
        
        str ~= '\0';

        scope (exit)
        {
            assert (str.length);
            assert (!str[$ - 1]);
            str.length = str.length - 1;
        }
        
        size_t end = str.length - 1;
        
        this.occurrences.length = 0;
        
        for (size_t pos = strcspn(str.ptr, Tokens.ptr); pos < end;)
        {
            this.occurrences ~= pos;

            pos += strcspn(str.ptr + ++pos, Tokens.ptr);
        }
        
        str.length = str.length + (this.occurrences.length * escape.length);
        
        str[$ - 1] = '\0'; // append a 0 to the end, as it is stripped in the scope(exit)
        
        foreach_reverse (i, occurrence; this.occurrences)
        {
            occurrence_ptr = str.ptr + occurrence;
            
            src = occurrence_ptr;
            dst = src + ((i + 1) * escape.length);
            
            size_t len = end - occurrence;

            memmove(dst, src, len);

            char* esc = dst - escape.length;
            esc[0..escape.length] = escape[];

            end = occurrence;
        }
        
        return str;
    }
}

version (None) unittest
{
    scope escape = new EscapeChars;
    
    char[] str = "\'\"abc'def\'\"".dup;
    
    Cerr(escape(str))("\n");
}