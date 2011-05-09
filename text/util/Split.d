/******************************************************************************

    String splitting utilities
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        February 2011: Initial release
    
    author:         David Eckardt
    
    - The SplitStr class splits a string by occurrences of a delimiter string.
    - The SplitChr class splits a string by occurrences of a delimiter
      character.
    
    Build note: Requires linking against libglib-2.0: add
    
        -L-lglib-2.0
        
    to the DMD build parameters.
    
    TODO: coordinate with ocean.core.Array and ocean.text.util.StringReplace
    
 ******************************************************************************/

module text.util.Split;

/******************************************************************************

    Imports

******************************************************************************/

private import ocean.core.Array: concat, copy;

private import tango.stdc.string: strlen, memchr, strcspn;
private import tango.stdc.ctype: isspace;

private import tango.stdc.posix.sys.types: ssize_t;

private import tango.io.Stdout;

/******************************************************************************

    Looks up the first occurrence of needle in haystack.
    
    Params:
        haystack     = string to search for needle
        haystack_len = length of haystack
        needle       = string to look up in haystack (must be NUL-terminated)
    
    Returns:
        first occurrence of needle in haystack or null of not found
    
 ******************************************************************************/

extern (C) private char* g_strstr_len ( char* haystack, ssize_t haystack_len, char* needle );

/******************************************************************************

    Splits a string by occurrences of a delimiter string

 ******************************************************************************/

class SplitStr : ISplit
{
    /**************************************************************************
        
        Delimiter string, always NUL-terminated
        
     **************************************************************************/
    
    private char[] delim_ =  "\0";
    
    /**************************************************************************
    
        Delimiter length (without NUL-terminator)
        
     **************************************************************************/

    private size_t delim_length = 0;
    
    /**************************************************************************
    
        Ensures that delim_ and delim_length are correct and consistent.
        
     **************************************************************************/

    invariant
    {
        assert (this.delim_.length);
        assert (!this.delim_[$ - 1]);
        assert (this.delim_length == strlen(this.delim_.ptr));
        assert (this.delim_length == this.delim_.length - 1);
    }
    
    /**************************************************************************
    
        Sets the delimiter string. delim_ may or may not be NUL-terminated;
        however, only the last character may be NUL.
        
        Params:
            delim_ = new delimiter string (will be copied into an internal
                     buffer)
        
        Returns:
            delim_
        
     **************************************************************************/
    
    public char[] delim ( char[] delim_ )
    in
    {
        if (delim_.length)
        {
            assert (!memchr(delim_.ptr, '\0', delim_.length - !delim_[$ - 1]),
                    "only the last character of the delimiter may be NUL");
        }
    }
    body
    {
        if (delim_.length)
        {
            if (delim_[$ - 1])
            {
                this.delim_.concat(delim_, "\0");
            }
            else
            {
                this.delim_.copy(delim_);
            }
        }
        else
        {
            this.delim_.copy("\0");
        }
        
        this.delim_length = this.delim_.length - 1;
        
        return delim_;
    }

    /**************************************************************************
    
        Returns:
            current delimiter string (without NUL-terminator; slices an internal
            buffer)
        
     **************************************************************************/

    public char[] delim ( )
    {
        return this.delim_[0 .. $ - 1];
    }
    
    /**************************************************************************
    
        Locates the first occurrence of the current delimiter string in str,
        starting from str[start].
        
        Params:
             str     = string to scan for delimiter
             start   = search start index
             
        Returns:
             index of first occurrence of the current delimiter string in str or
             str.length if not found
                          
     **************************************************************************/
    
    public size_t locateDelim ( char[] str, size_t start = 0 )
    {
        return this.delim_length? this.locateDelim(str, this.delim_, start) : str.length;
    }
    
    /**************************************************************************
    
        Locates the first occurrence of delim in str, starting from str[start].
        
        Template params:
            delim = delimiter string
        
        Params:
             str     = string to scan for delimiter
             start   = search start index
             
        Returns:
             index of first occurrence of delim in str or str.length if not
             found
                          
     **************************************************************************/

    public static size_t locateDelimT ( char[] delim ) ( char[] str, size_t start = 0 )
    {
        return locateDelim(str, delim, start);
    }
    
    /**************************************************************************
    
        Skips the delimiter which str starts with.
        Note that the result is correct only if str really starts with a
        delimiter.
        
        Params:
            str = string starting with delimiter
            
        Returns:
            index of the first character after the starting delimiter in str
                          
     **************************************************************************/

    protected size_t skipDelim ( char[] str )
    in
    {
        assert (str.length >= this.delim_length);
    }
    body
    {
        return this.delim_length;
    }
    
    /**************************************************************************
    
        Locates the first occurrence of delim in str, starting from str[start].
        
        Params:
             str   = string to scan for delimiter
             delim = delimiter; MUST be NUL-terminated
             start = search start index
             
        Returns:
             index of first occurrence of delim in str or str.length if not
             found
        
        Note:
            NUL-termination of delim cannot be checked because there is no safe
            method of detecting the NUL-terminator that follows string literals
            ('*(delim.ptr + delim.length) == '\0'' would be dangerous if delim
            is not a string literal). So, unfortunately, NUL-termination of
            delim cannot be ensured by assert().
        
     **************************************************************************/

    private static size_t locateDelim ( char[] str, char[] delim, size_t start = 0 )
    in
    {
        assert (start < str.length, typeof (this).stringof ~ ".locateDelim: start index out of range");
    }
    body
    {
        char* item = g_strstr_len(str.ptr + start, str.length - start, delim.ptr);
        
        return item? item - str.ptr : str.length;
    }
    
    unittest
    {
        with (new typeof (this))
        {
            collapse = true;
            
            delim = "123";
            
            Stderr(split("abcd123ghi"))("\n").flush();
        }
    }
}

/******************************************************************************

    Splits a string by occurrences of a delimiter character

 ******************************************************************************/

class SplitChr : ISplit
{
    /**************************************************************************
        
        Delimiter character
        
     **************************************************************************/
    
    char delim;
    
    /**************************************************************************
    
        Locates the first occurrence of delim in str starting with str[start].
        
        Params:
             str   = string to scan
             start = search start index
             
        Returns:
             index of first occurrence of delim in str or str.length if not
             found
                          
     **************************************************************************/
    
    public size_t locateDelim ( char[] str, size_t start = 0 )
    in
    {
        assert (start < str.length, typeof (this).stringof ~ ".locateDelim: start index out of range");
    }
    body
    {
        char* item = cast (char*) memchr(str.ptr + start, this.delim, str.length - start);
        
        return item? item - str.ptr : str.length;
    }
    
    /**************************************************************************
    
        Skips the delimiter which str starts with.
        Note that the result is correct only if str really starts with a
        delimiter.
        
        Params:
            str = string starting with delimiter
            
        Returns:
            index of the first character after the starting delimiter in str
                          
     **************************************************************************/

    protected size_t skipDelim ( char[] str )
    in
    {
        assert (str.length >= 1);
    }
    body
    {
        return 1;
    }
}

/******************************************************************************

    Base class

 ******************************************************************************/

abstract class ISplit
{
    /**************************************************************************
    
        Set to true to collapse consecutive delimiter occurrences to a single
        one to prevent producing empty segments.
         
     **************************************************************************/

    public bool collapse = false;
    
    /**************************************************************************
    
        Maximum number of resulting segments
         
     **************************************************************************/

    public uint n = uint.max;
    
    /**************************************************************************
    
        List of resulting segments
         
     **************************************************************************/

    protected char[][] segments_;
    
    /**************************************************************************
    
        Ensures that the maximum number of resulting segments is observed.
         
     **************************************************************************/

    invariant
    {
        assert (this.n <= this.segments.length);
    }
    
    /**************************************************************************
    
        Returns:
            split segments resulting from last split() invocation or null if
            split() has not been invoked yet
         
     **************************************************************************/

    public char[][] segments ( )
    {
        return this.segments_;
    }
    
    /**************************************************************************
    
        Resets the resulting split segments to an empty list.
        
        Returns:
            this instance
         
     **************************************************************************/

    public typeof (this) reset ( )
    {
        this.segments_.length = 0;
        
        return this;
    }

    /**************************************************************************
    
        Splits str into at most n segments on each delimiter occurrence.
        
        Params:
             str = string to split
         
        Returns:
            resulting split segments
         
     **************************************************************************/

    char[][] split ( char[] str )
    {
        this.segments_.length = 0;
        
        if (str.length)
        {
            uint   i     = 0;
            
            size_t start = this.collapse? this.skipLeadingDelims(str) : 0;
            
            size_t pos   = this.locateDelim(str, start);
            
            while ((pos < str.length) && (!this.n || (i < this.n)))
            {
                if (!((pos == start) && collapse))
                {
                    this.segments_ ~= str[start .. pos];
                    
                    i++;
                }
            
                version (all)
                {
                    start = pos + this.skipDelim(str[pos .. $]);
                }
                else
                {
                    start = pos + 1;
                }
                
                pos = this.locateDelim(str, start);
            }
            
            if ((!this.n || (i < this.n)) &&
                (!((start == str.length) && this.collapse)))
            {
                this.segments_ ~= str[start .. $];                              // append tail
            }
        }
        
        return this.segments_;
    }
    
    alias split opCall;
    
    /**************************************************************************
    
        Locates the first delimiter occurrence in str starting from str[start].
        
        Params:
            str   = str to locate first delimiter occurrence in
            start = start index
            
        Returns:
            index of the first delimiter occurrence in str or str.length if not
            found
         
     **************************************************************************/

    abstract size_t locateDelim ( char[] str, size_t start = 0 );
    
    /**************************************************************************
    
        Skips initial consecutive occurrences of the current delimiter in str.
        
        Params:
             str = string to skip initial consecutive occurrences of the current
                   delimiter in
        
        Returns:
             index of first occurrence of delim in str or str.length if not
             found
                          
     **************************************************************************/

    public size_t skipLeadingDelims ( char[] str )
    {
        size_t start = 0,
               pos   = this.locateDelim(str);
        
        while (pos == start)
        {
            start = pos + this.skipDelim(str[pos .. $]);
            
            pos = this.locateDelim(str, start);
        }
        
        return start;
    }
    
    /**************************************************************************
    
        Skips the delimiter which str starts with.
        The return value is at most str.length.
        It is assured that str starts with a delimiter so a subclass may return
        an undefined result otherwise. Additionally, a subclass is encouraged to
        use an 'in' contract to ensure str starts with a delimiter and/or is
        long enought to skip a leading delimiter. 
        
        Params:
            str = string starting with delimiter
            
        Returns:
            index of the first character after the starting delimiter in str
        
     **************************************************************************/

    abstract protected size_t skipDelim ( char[] str );
    
    /***************************************************************************
    
        Trims white space from str.
        
        Params:
             str       = input string
                     
        Returns:
             the resulting string
             
    ***************************************************************************/
    
    static char[] trim ( char[] str )
    {
        foreach_reverse (i, c; str)
        {
            if (!isspace(c))
            {
                str = str[0 .. i + 1];
                break;
            }
        }
        
        foreach (i, c; str)
        {
            if (!isspace(c))
            {
                return str[i .. $];
            }
        }
        
        return "";                                                              
    }

}

/+
import tango.io.Stdout;
import tango.io.Console;

unittest
{
Substitute substitute;

substitute.delims = "Katze";

scope str = "Katze tritt Katze die Treppe Katze krumm. Katze".dup;

Cout(substitute(str, "Klaus"))("\n");

//substitute.delims = "";

//Cout(substitute(str, ""))("\n");
}
+/