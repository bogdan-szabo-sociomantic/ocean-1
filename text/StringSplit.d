/******************************************************************************

    Locate character in string and split string by delimiter character

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved
    
    version:        January 2010: Initial release
    
    authors:        David Eckardt
    
 ******************************************************************************/

module ocean.text.StringSplit;

/******************************************************************************

    Imports

 ******************************************************************************/

private import           tango.stdc.stddef: wchar_t;
private import Cstring = tango.stdc.string: memchr, wmemchr;

private import           tango.math.Math:   min;

/******************************************************************************

    CatSplit structure
    
    Char is the character base type; the following types are supported:
    - char for single-byte characters (default),
    - either dchar or wchar for multi-byte characters.
    The supported multi-byte character type (dchar or wchar) is platform
    dependent and is determined by the "wchar_t" alias definition in
    tango.stdc.string. In general, it is dchar for Posix and wchar for Win32.

 ******************************************************************************/

struct StringSplit ( Char = char )
{
    /**************************************************************************

        Char type validation
    
     **************************************************************************/

    static if (is (Char == char))
    {
        alias Cstring.memchr pLocateBinChar;
    }
    else static if (is (Char == wchar_t))
    {
        alias Cstring.wmemchr pLocateBinChar;
    }
    else static assert (false, typeof (*this).stringof ~ ": Char must be 'char' "
                               "or '" ~ wchar_t.stringof ~ "', not '" ~ Char.stringof ~ '\'');
    
    /**************************************************************************
        
        Locates the first occurence of value within the first length
        characters of str starting from start.
        
        Params:
             str    = string to search for "value"
             value  = element value to find
             length = number of elements to examine (truncated to length of str)
            
        Returns:
             the index of the first element with value "value" or the index of
             the last examined element + 1

     **************************************************************************/
    
    public static size_t locateChar ( Char[] str, Char value,
                                      size_t start  = 0, 
                                      size_t length = size_t.max )
    in
    {
        assert (start <= str.length, typeof (*this).stringof ~ ".locateChar(): "
                                     "start index out of range");
    }
    body
    {
        length = min(length, str.length);
        
        void* item = pLocateBinChar(str.ptr + start, value, length - start);
        
        return item? (item - str.ptr) : length;
    }
    
    
    /**************************************************************************
    
        Tells whether str contains value.
        
        Params:
            str   = string to search for value
            value = value to search for
            start = search start index
            
        Returns:
             true if str contains value or false otherwise

     **************************************************************************/
    
    public static bool containsChar ( Char[] str, Char value, size_t start = 0 )
    in
    {
        assert (start <= str.length, typeof (*this).stringof ~ ".containsChar(): "
                                     "start index out of range");
    }
    body
    {
        return !!pLocateBinChar(str.ptr + start, value, str.length - start);
    }
    
    
    
    /**************************************************************************
      
        Splits "str" into at most "n" "slices" on each occurrence of "delim".
        "collapse" indicates whether to collapse consecutive occurrences  to a
        single one to prevent producing empty slices.
        
        Params:
             str      = input string
             delim    = delimiter character
             n        = maximum number of slices; set to 0 to indicate no limit
             collapse = set to true to collapse consecutive occurrences to
                        prevent producing empty "slices"
            
        Returns:
             the resulting slices

     **************************************************************************/
    
    public static Char[][] split ( Char[] str, Char delim, uint n = 0, bool collapse = false )
    {
        Char[][] slices;
        
        uint   i     = 0;
        
        size_t start = collapse? skipLeadingDelims(str, delim) : 0;
        
        size_t pos   = locateChar(str, delim, start);
        
        while ((pos < str.length) && (!n || (i < n)))
        {
            if (!((pos == start) && collapse))
            {
                slices ~= str[start .. pos];
                
                i++;
            }
        
            start = pos + 1;
            
            pos = locateChar(str, delim, start);
        }
        
        
        if ((!n || (i < n)) && (!((start == str.length) && collapse)))
        {
            slices ~= str[start .. $];                         // append tail
        }
        
        return slices;
    }
    
    /**************************************************************************
        
        Splits "str" into at most "n" "slices" on each occurrence of "delim".
        Consecutive occurrences are collapsed  to a single one to prevent
        producing empty slices.
        
        Params:
             slices   = array to put the resulting slices
             str      = input string
             delim    = delimiter character
             n        = maximum number of slices; set to 0 to indicate no limit
            
        Returns:
             the resulting slices
     
     **************************************************************************/
    
    public static Char[][] splitCollapse ( Char[] str, Char delim, uint n = 0 )
    {
        return split(str, delim, n, true);
    }
    
    /**************************************************************************
    
        Skips leading occurrences of delim in string.
        
        Params:
             str      = input string
             delim    = delimiter character
            
        Returns:
             index of character in str after skipping leading occurrences of
             delim (length of str if str consists of delim characters)
     
     **************************************************************************/
    
    private static size_t skipLeadingDelims ( Char[] str, Char delim )
    {
        foreach (i, c; str)          // skip leading consecutive occurrences
        {
            if (c != delim) return i;
        }
        
        return str.length;
    }
}