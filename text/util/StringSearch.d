/******************************************************************************
    
    C string and character tool functions
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        October 2009: Initial release

    author:         David Eckardt

    --
    
    Description:
    
    C string and character tool functions and null terminator utilities
    
 ******************************************************************************/

module ocean.text.util.StringSearch;

/******************************************************************************

    Imports

 ******************************************************************************/

private import cstddef = tango.stdc.stddef: wchar_t;
private import cwctype = tango.stdc.wctype;
private import cctype  = tango.stdc.ctype;
private import cstring = tango.stdc.string;

private import           tango.math.Math:   min;

/++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    /**************************************************************************

        Descriptions for public alias methods

     **************************************************************************/
     
    /**
     * Returns the length of "str" without null terminator.
     * 
     * Params:
     *      str = string (must be null terminated)
     *
     * Returns:
     *      length of "str" without null terminator
     */
    size_t lengthOf ( Char* str );
    
    
    /**
     * Tells whether "chr" is
     *  isCntrl -- a control character or
     *  isSpace -- whitespace or
     *  isGraph -- a character associated with a graph or
     *  isPrint -- printable or
     *  isAlpha -- a letter or
     *  isLower -- a lower case letter or
     *  isUpper -- an upper case letter or
     *  isAlNum -- a letter or a decimal digit or
     *  isDigit -- a decimalt digit or
     *  isHexDigit -- a hexadecimal digit.
     * 
     * Params:
     *      chr = character to identify
     * Returns:
     *      true if the character is of the specified class or false otherwise
     */
    bool isCntrl ( Char chr );
    bool isSpace ( Char chr );
    
    bool isGraph ( Char chr );
    bool isPrint ( Char chr );
    bool isPunct ( Char chr );
    
    bool isAlpha ( Char chr );
    bool isAlNum ( Char chr );
    bool isDigit ( Char chr );
    bool isHexDigit ( Char chr );
    
    
    bool isLower ( Char chr );
    bool isUpper ( Char chr );
    
    
    /**
     * Converts "chr"
     *  toLower -- to lower case or
     *  toUpper -- to upper case.
     * 
     * Params:
     *      chr = character to convert
     *
     * Returns:
     *      converted character
     */
    Char toLower ( Char chr );
    Char toUpper ( Char chr );
    
    
    /**************************************************************************

        Explanations for private alias methods

     **************************************************************************/
     
    /**
     * Returns the index of the first occurrence of one of the characters in
     * "charset" in "str".
     * 
     * Params:
     *     str =     string to scan for characters in "charset"
     *     charset = search character set
     * Returns:
     */
    size_t pLocateFirstInSet ( Char* str, Char* charset );
    
    
    /**
     * Returns a pointer to the first occurrence of "pattern" in "str".
     *
     * Params:
     *     str = string to scan for "pattern"
     *     pattern = search pattern
     * Returns:
     */
    Char* pLocatePattern ( Char* str, Char* pattern );
    
    
    /**
     * Moves src[0 .. n] to dst[0 .. n]. "src" and "dst" may overlap.
     * 
     * Params:
     *     dst = pointer to destination
     *     src = pointer to source
     *     n   = number of elements to move
     * Returns:
     */
    Char* pMemMove ( Char* dst, Char* src, size_t n );
    
    
    /**
     * Returns a pointer to the first occurrence of "chr" within the first "n"
     * elements of "str".
     * 
     * Params:
     *     str = string to scan for "chr"
     *     chr = search character
     *     n =   number of characters to scan for "chr"
     * Returns:
     */
    Char* pLocateBinChar ( Char* str, Char chr, size_t n );
    
    
 ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++/

/******************************************************************************

    StringSearch structure
        
 ******************************************************************************/

struct StringSearch ( bool wide_char = false )
{
    alias cstddef.wchar_t WcharT;
    
    static if (wide_char)
    {
        alias WcharT            Char;
        
        alias cwctype.iswcntrl  isCntrl;
        alias cwctype.iswspace  isSpace;
        
        alias cwctype.iswgraph  isGraph;
        alias cwctype.iswprint  isPrint;
        alias cwctype.iswpunct  isPunct;
    
        alias cwctype.iswalpha  isAlpha;
        alias cwctype.iswalnum  isAlNum;
        alias cwctype.iswdigit  isDigit;
        alias cwctype.iswxdigit isHexDigit;
        
        alias cwctype.iswlower  isLower;
        alias cwctype.iswupper  isUpper;
        
        alias cwctype.towlower  toLower;
        alias cwctype.towupper  toUpper;
        
        alias cstring.wcslen    lengthOf;
        
        alias cstring.wmemchr   pLocateBinChar;
        
        alias cstring.wcsstr    pLocatePattern;
        alias cstring.wmemmove  pMemMove;
        alias cstring.wcscspn   pLocateFirstInSet;
    }
    else
    {
        alias char              Char;
        
        alias cctype.iscntrl    isCntrl;
        alias cctype.isspace    isSpace;
        
        alias cctype.isgraph    isGraph;
        alias cctype.isprint    isPrint;
        alias cctype.ispunct    isPunct;
    
        alias cctype.isalpha    isAlpha;
        alias cctype.isalnum    isAlNum;
        alias cctype.isdigit    isDigit;
        alias cctype.isxdigit   isHexDigit;
        
        alias cctype.islower    isLower;
        alias cctype.isupper    isUpper;
        
        alias cctype.tolower    toLower;
        alias cctype.toupper    toUpper;
        
        alias cstring.strlen    lengthOf;
        
        alias cstring.memchr    pLocateBinChar;
        
        alias cstring.strstr    pLocatePattern;
        alias cstring.memmove   pMemMove;
        alias cstring.strcspn   pLocateFirstInSet;
    }
    
    static const Char TERM = '\0';
    
    /**
     * Locates the first occurence of "value" within the first "length"
     * characters of "str". If "length" is greater than the length of "str",
     * it is set to the length of "str".
     * 
     * Params:
     *      str    = string to search for "value"
     *      value  = element value to find
     *      length = number of elements to examine (at most length of "str")
     *     
     * Returns:
     *      the index of the first element with value "value" or the index of
     *      the last examined element + 1
     */
    public static size_t locateChar ( Char[] str, Char value,
                                      size_t start  = 0, 
                                      size_t length = size_t.max )
    in
    {
        assert (start <= str.length, this.THIS_STR ~ "locateChar(): start index out of range");
    }
    body
    {
        length = min(length, str.length);
        
        void* item = pLocateBinChar(str.ptr + start, value, length - start);
        
        return item? (item - str.ptr) : length;
    }
    
    
    /**
     * Tells whether str contains value.
     * 
     * Params:
     *     str   = string to search for value
     *     value = value to search for
     *     start = start index
     *     
     * Returns:
     *      true if str contains value or false otherwise
     */
    public static bool containsChar ( Char[] str, Char value, size_t start = 0 )
    in
    {
        assert (start <= str.length, this.THIS_STR ~ "charInSet(): start index out of range");
    }
    body
    {
        return !!pLocateBinChar(str.ptr + start, value, str.length - start);
    }
    
    
    /**
     * Scans "str" for "pattern" and returns the index of the first occurrence
     * if found. 
     * 
     * Params:
     *      str     = string to scan
     *      pattern = search pattern
     *      
     * Returns:
     *      If found, the index of the first occurrence, or the length of "str"
     *      otherwise.
     */
    public static size_t locatePattern ( Char[] str, Char[] pattern, size_t start = 0 )
    {
        if (str.length)
        {
            start = min(start, str.length - 1);
        }
        
        Char[] str_search = str[start .. $] ~ TERM;
        
        Char* item = pLocatePattern(str_search.ptr, (pattern ~ TERM).ptr);
        
        return item? ((item - str_search.ptr) + start) : str.length;
    }
    
    
    
    /**
     * Tells whether "str" contains "pattern".
     * 
     * Params:
     *      str     = string to scan
     *      pattern = search pattern
     *      
     * Returns:
     *      true if "str" contains "pattern" or false otherwise
     */
    public static bool containsPattern ( Char[] str, Char[] pattern )
    {
        return !!pLocatePattern((str ~ this.TERM).ptr, (pattern ~ this.TERM).ptr);
    }
    
    
    public static size_t locateCharSet ( Char[] str, Char[] charset )
    {
        return pLocateFirstInSet((str ~ this.TERM).ptr, (charset ~ this.TERM).ptr);
    }
    
    
    public static size_t locateCharSetT ( Char[] charset ) ( Char[] str )
    {
        return pLocateFirstInSet((str ~ this.TERM).ptr, charset.ptr);
    }
    
    
    /**
     * Shifts "length" characters inside "string" from "src_pos" to "dst_pos".
     * This effectively does the same thing as
     * 
     * ---
     *      string[src_pos .. src_pos + length] =  string[dst_pos .. dst_pos + length];
     * ---
     * 
     * but allows overlapping ranges.
     * 
     * Params:
     *     string  = string to process
     *     dst_pos = destination start position (index) 
     *     src_pos = source start position (index)
     *     length  = number of array elements to shift
     */
    public static Char[] shiftString ( ref Char[] str, size_t dst_pos,
                                     size_t src_pos, size_t length )
    in
    {
        static const PREFIX = this.THIS_STR ~ ".shiftString(): ";
        
        assert (src_pos <= str.length, PREFIX ~ "source start out of range");
        assert (dst_pos <= str.length, PREFIX ~ "destination start out of range");
        assert (src_pos + length <= str.length, PREFIX ~ "source end out of range");
        assert (dst_pos + length <= str.length, PREFIX ~ "destination end out of range");
    }
    body
    {
        pMemMove(str.ptr + dst_pos, str.ptr + src_pos, length);
        
        return str;
    }
    
    
    
    /**
     * Returns the length of "str" without null terminator.
     * 
     * Params:
     *      str = input string (may or may not be null terminated)
     *       
     * Returns:
     *      the length of the string of this segment
     */
    public static size_t lengthOf ( Char[] str )
    {
        return str.length? (str[$ - 1]? str.length : lengthOf(str.ptr)) : 0;
    }
    
    
    
    /**
     * Strips the null terminator from "str".
     * 
     * Params:
     *      str = input string
     *      
     * Returns:
     *      stripped string
     */
    public static Char[] stripTerm ( Char[] str )
    {
        return str[0 .. lengthOf(str)];
    }
    
    
    
    /**
     * Tells whether "str" is null-terminated.
     * 
     * Params:
     *      str = input string
     *       
     * Returns:
     *      true if "str" is null-terminated or false otherwise
     *      
     */
    public static bool hasTerm ( Char[] str )
    {
        return str.length? !str[$ - 1] : false;
    }
    
    
    
    /**
     * Asserts that "str" is null-terminated.
     * 
     * Params:
     *     str = input string
     */
    public static void assertTerm ( char[] func ) ( Char[] str )
    {
        assert (hasTerm(str), msgFunc!(func) ~ ": unterminated string");
    }

    
    
    /**
     * Tells whether "str" and "pattern" are equal regardless of null
     * terminators.
     * 
     * Params:
     *      str     = str to compare to "pattern"
     *      pattern = comparison pattern for "str"
     *      
     * Returns:
     *      true on match or false otherwise
     */
    public static bool matches ( Char[] str, Char[] pattern )
    {
        return (stripTerm(str) == stripTerm(pattern));
    }
   
    
    
   /**
    * Trims white space from "str".
    * 
    * Params:
    *      str       = input string
    *      terminate = set to true to null-terminate the resulting string if
    *                  the input string is null-terminated
    *              
    * Returns:
    *      the resulting string
    */
    public static Char[] trim ( Char[] str, bool terminate = false )
    {
        terminate &= hasTerm(str);
        
        foreach_reverse (i, c; str[0 .. lengthOf(str)])
        {
            if (!isSpace(c))
            {
                str = str[0 .. i + terminate + 1];
                break;
            }
        }
        
        foreach (i, c; str)
        {
            if (!isSpace(c))
            {
                return str[i .. $];
            }
        }
        
        return "";
    }
    
    
    
    /**
     * Converts each character of "str" in-place using "convert". "convert"
     * must be something that takes a character in the first argument and
     * returns the converted character.
     * 
     * Params:
     *      str = string to convert
     *       
     * Returns:
     *      converted string
     */
    public static Char[] charConv ( alias convert ) ( ref Char[] str )
    {
        foreach (ref c; str)
        {
            c = convert(c);
        }
        
        return str;
    }
    /**
     * Converts "str" in-place to lower case.
     * 
     * Params:
     *      str = string to convert
     *       
     * Returns:
     *      converted string
     */
    alias charConv!(toLower) strToLower;
    /**
     * Converts "str" in-place to upper case.
     * 
     * Params:
     *      str = string to convert
     *       
     * Returns:
     *      converted string
     */
    alias charConv!(toUpper) strToUpper;
    
    
    
    /**
     * Tells if all letter characters in "str" match the condition checked by
     * "check". "check" must be something that takes a character in the first
     * argument and returns an integer type where a value different from 0 means
     * that the condition is satisfied. 
     * 
     * Params:
     *      str = string to convert
     *       
     * Returns:
     *      true if all letter characters match the the condition checked by
     *      "check" or false otherwise
     */
    public static bool caseCheck ( alias check ) ( Char[] str )
    {
        bool result = true;
        
        foreach (c; str)
        {
            result &= (!isAlpha(c) || !!check(c));
        }
        
        return result;
    }
    /**
     * Checks if all letter characters in "str" are lower case.
     * 
     * Params:
     *      str = string to check
     *       
     * Returns:
     *      true if all letter characters in "str" are lower case or false
     *      otherwise
     */
    alias caseCheck!(isLower) strIsLower;
    /**
     * Checks if all letter characters in "str" are upper case.
     * 
     * Params:
     *      str = string to check
     *       
     * Returns:
     *      true if all letter characters in "str" are upper case or false
     *      otherwise
     */
    alias caseCheck!(isUpper) strIsUpper;

    
    /**
     * Splits "str" into at most "n" "slices" on each occurrence of "delim".
     * "collapse" indicates whether to collapse consecutive occurrences  to a
     * single one to prevent producing empty slices.
     * 
     * Params:
     *      slices   = array to put the resulting slices
     *      str      = input string
     *      delim    = delimiter character
     *      n        = maximum number of slices; set to 0 to indicate no limit
     *      collapse = set to true to collapse consecutive occurrences to
     *                 prevent producing empty "slices"
     *     
     * Returns:
     *      the resulting slices
     */
    public static Char[][] split ( Char[][] slices, Char[] str, Char delim, uint n, bool collapse )
    {
        uint i = 0;
        
        size_t prev_pos = 0;
        
        slices.length = 0;
        
        if (collapse)
        {
            foreach (j, c; str)          // skip leading consecutive occurrences
            {
                if (c != delim)
                {
                    prev_pos = j;
                    
                    break;
                }
            }
        }
        
        for (size_t pos = locateChar(str, delim);
                    (pos < str.length) && (!n || (i < n));
                    pos = locateChar(str, delim, prev_pos))
        {
            if (!((pos == prev_pos) && collapse))
            {
                slices ~= str[prev_pos .. pos];
                
                i++;
            }
            
            prev_pos = pos + 1;
        }
        
        if ((!n || (i < n)) && (!((prev_pos == str.length) && collapse)))
        {
            slices ~= str[prev_pos .. $];
        }
        
        
        return slices;
    }
    
    
    
    /**
     * Splits "str" into at most "n" "slices" on each occurrence of "delim".
     * 
     * Params:
     *      slices   = array to put the resulting slices
     *      str      = input string
     *      delim    = delimiter character
     *      n        = maximum number of slices; set to 0 to indicate no limit
     *     
     * Returns:
     *      the resulting slices
     */
    public static Char[][] split ( Char[][] slices, Char[] str, Char delim, uint n = 0 )
    {
        return split(slices, str, delim, n, false);
    }
    
    
    
    /**
     * Splits "str" into at most "n" "slices" on each occurrence of "delim".
     * Consecutive occurrences are collapsed  to a single one to prevent
     * producing empty slices.
     * 
     * Params:
     *      slices   = array to put the resulting slices
     *      str      = input string
     *      delim    = delimiter character
     *      n        = maximum number of slices; set to 0 to indicate no limit
     *     
     * Returns:
     *      the resulting slices
     */
    public static Char[][] splitCollapse ( Char[][] slices, Char[] str, Char delim, uint n = 0 )
    {
        return split(slices, str, delim, n, true);
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

    /**************************************************************************

        Name string of this for message generation
    
     **************************************************************************/
    
    private static const THIS_STR = typeof (*this).stringof;
}
