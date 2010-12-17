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

    public char[] opCall ( ref char[] str )
    {
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
        
        str.length = str.length + this.occurrences.length;
        
        str[$ - 1] = '\0';
        
        foreach_reverse (i, item; this.occurrences)
        {
            char* item_ptr = str.ptr + item;
            
            memmove(item_ptr + i + 1, item_ptr, end - item);
            
            item_ptr[i] = '\\';
            
            end = item;
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