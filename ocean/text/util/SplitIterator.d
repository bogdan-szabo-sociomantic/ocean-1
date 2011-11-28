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
    
 ******************************************************************************/

module ocean.text.util.SplitIterator;

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
    
    @see http://www.gtk.org/api/2.6/glib/glib-String-Utility-Functions.html#g-strstr-len
    
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

class StrSplitIterator : ISplitIterator
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
    
    /**************************************************************************/
    
    version (none) unittest
    {
        scope split = new typeof (this);
        
        void check ( char[] str, char[][] elements, char[] line )
        {
            foreach (element; split.reset(str)) try
            {
                assert (split.n, test_id);
                assert (split.n <= elements.length, test_id);
                assert (element == elements[split.n - 1], test_id);
            }
            catch (Exception e)
            {
                e.msg ~= " at line  ";
                e.msg ~= line;
            }
        }
        
        split.delim    = "123";

        split.collapse = true;
                
        foreach (str; ["123""ab""123"     "cd""123""efg""123",
                       "123""ab""123""123""cd""123""efg""123",
                       "123""ab""123""123""cd""123""efg",
                            "ab""123""123""cd""123""efg",
                       
                       "123""123""ab""123""123""cd""123""efg",
                       "ab""123""123""cd""123""efg""123""123"])
        {
            version (all)
            {
                check(str, ["ab", "cd", "efg"]);
            }
            else foreach (element; split.reset(str))
            {
                const char[][] elements = ["ab", "cd", "efg"];
                
                assert (split.n);
                assert (split.n <= elements.length);
                assert (element == elements[split.n - 1]);
            }
        }
        
        split.collapse = false;
        
        foreach (element; split.reset("ab""123""cd""123""efg"))
        {
            const char[][] elements = ["ab", "cd", "efg"];
            
            assert (split.n);
            assert (split.n <= elements.length);
            assert (element == elements[split.n - 1]);
        }
        
        foreach (element; split.reset("123""ab""123""cd""123""efg""123"))
        {
            const char[][] elements = ["", "ab", "cd", "efg", ""];
            
            assert (split.n);
            assert (split.n <= elements.length);
            assert (element == elements[split.n - 1]);
        }
        
        version (none)
        {
//            collapse = true;
//            
            delim = "123";
//            
//            Stderr(split("123ab123123cd123efg123"))("\n").flush();
//            
//            collapse = false;
//            
//            Stderr(split("123ab123123cd123efg123"))("\n").flush();
//            Stderr(split("ab123123cd123efg123"))("\n").flush();
//            Stderr(split("123ab123123cd123efg"))("\n").flush();
//            Stderr(split("ab123123cd123efg"))("\n").flush();
            
            collapse = true;
//            n = 2;
//            
//            Stderr(split("123ab123123cd123efg"));
//            Stderr(" ")(remaining)("\n").flush();
        }
    }
}

/******************************************************************************

    Splits a string by occurrences of a delimiter character

 ******************************************************************************/

class ChrSplitIterator : ISplitIterator
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

abstract class ISplitIterator
{
    /**************************************************************************
    
        Set to true to collapse consecutive delimiter occurrences to a single
        one to prevent producing empty segments.
         
     **************************************************************************/

    public bool collapse = false;
    
    /**************************************************************************
    
        Set to true to do a 'foreach' cycle with the remaining content after
        the last delimiter occurrence or when no delimiter is found.
         
     **************************************************************************/

    public bool include_remaining = true;
    
    /**************************************************************************
    
        String to split on next iteration and slice to remaining content.
         
     **************************************************************************/

    private char[] content, remaining_;
    
    /**************************************************************************
    
        'foreach' iteration counter 
         
     **************************************************************************/

    private uint n_ = 0;
    
    /**************************************************************************
    
        Consistency check 
         
     **************************************************************************/

    invariant ( )
    {
        if (this.n_)
        {
            assert (this.remaining_);
            assert (this.content);
            assert (this.remaining_.length <= this.content.length);
            
            if (this.remaining_.length)
            {
                assert (&this.remaining_[$ - 1] is &this.content[$ - 1]);
            }
        }
        else
        {
            assert (this.remaining_ == this.content);
        }
    }
    
    /**************************************************************************
    
        Sets the content string to split on next iteration.
        
        Params:
            content = Content string to split; pass null to clear the content.
                      content will be sliced (not copied).
        
        Returns:
            this instance
         
     **************************************************************************/

    public typeof (this) reset ( char[] content = null )
    {
        this.content    = content;
        this.remaining_ = this.content;
        this.n_         = 0;
        
        return this;
    }
    
    /**************************************************************************
    
        'foreach' iteration over string slices between the current and the next
        delimiter. n() returns the number of 'foreach' loop cycles so far,
        remaining() the slice after the next delimiter to the content end.
        If no delimiter was found, n() is 0 after 'foreach' has finished and
        remaining() returns the content. 
         
     **************************************************************************/

    int opApply ( int delegate ( ref char[] segment ) dg )
    {
        int result = 0;
        
        if (this.content.length)
        {
            this.n_  = 0;
            
            size_t start = this.collapse? this.skipLeadingDelims(this.content) : 0;
            
            for (size_t pos = this.locateDelim(this.content, start);
                        pos < this.content.length;
                        pos = this.locateDelim(this.content, start))
            {
                size_t next = pos + this.skipDelim(this.content[pos .. $]);
                
                if (!(pos == start && collapse))
                {
                    this.n_++;
                    
                    char[] segment  = this.content[start ..  pos];
                    this.remaining_ = this.content[next .. $];
                    
                    result = dg(segment);
                }
                
                start = next;
                
                if (result || start >= this.content.length) break;
            }
            
            if (this.include_remaining &&
                !(result || (start >= this.content.length && this.collapse)))
            {
                this.n_++;
                
                result = dg(this.remaining_);
                
                this.remaining_ = "";
            }
        }
        
        return result;
    }
    
    /**************************************************************************
    
        Returns:
            the number of 'foreach' loop cycles so far. If the value is 0,
            either no 'foreach' iteration has been done since last reset() or
            there is no delimiter occurrence in the content string. remaining()
            will then return the content string.
         
     **************************************************************************/
    
    public uint n ( )
    {
        return this.n_;
    }

    /**************************************************************************
    
        Returns:
            - a slice to the content string after the next delimiter when
              currently doing a 'foreach' iteration,
            - a slice to the content string after the last delimiter after a
              'foreach' iteration has finished,
            - the content string if no 'foreach' iteration has been done or
              there is no delimiter occurrence in the content string.
         
     **************************************************************************/

    public char[] remaining ( )
    {
        return this.remaining_;
    }
    
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
        
        return str? str[0 .. 0] : null;                                                              
    }

}
