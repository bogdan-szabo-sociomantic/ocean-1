/******************************************************************************
    
    String search and replace methods
    
    --
    
    StringReplace.d is

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        October 2009: Initial release

    author:         David Eckardt

    --
    
    Description:

    String search and replace functions with the following special features:
    
        - Replacement is completely done in-place without any temporary buffer.
        - The replacement may be shorter or longer than the search pattern;
          if so, the string length is automatically increased or decreased. 
    
    --
    
    Usage:
    
    ---
        
        dchar[] content;
        
        StringReplace!(dchar) replace = new StringReplace!(dchar);
        
        // fill "content" with text
        
        replace.replacePattern(content, "Max", "Moritz");
        
        // all occurrences of "Max" in "content" are now replaced by "Moritz"
        
    ---
    
 ******************************************************************************/

module ocean.text.StringReplace;

private import tango.stdc.stddef: wchar_t;
private import tango.stdc.string: memmove, wmemmove,
                                  strstr,  wcsstr,
                                  strcspn, wcscspn;

class StringReplace ( T )
{
    /**************************************************************************

        Aliases

     **************************************************************************/
    
    
    /**************************************************************************
        
        Aliases for byte/wide character C string functions.
        
        wchar_t is an alias of dchar or wchar, depending on platform; see
        tango.stdc.stddef
        
     **************************************************************************/
    
    static if (is (T == char))
    {
        private alias memmove Wmemmove;
        private alias strstr  Wcsstr;
        private alias strcspn Wcscspn;
    }
    else
    {
        static assert (is (T == wchar_t), typeof (this).stringof ~ ": type '" ~
                                          T.stringof ~
                                          "' not supported; please use '" ~
                                          wchar_t.stringof ~ "'");
        private alias wmemmove Wmemmove;
        private alias wcsstr   Wcsstr;
        private alias wcscspn  Wcscspn;
    }
    
    
    
    /**************************************************************************
     
        Decoder delegate signature for replaceDecode functions.
    
     **************************************************************************/
    
    alias size_t delegate ( ref T[] input, size_t source_pos, size_t destin_pos ) Decoder;
    
    
    /**************************************************************************
    
        List of search pattern/characters occurrences found.
    
     **************************************************************************/
    
    private size_t[] items;
    
    
    /**************************************************************************
     
         Constructor: nothing to do
     
     **************************************************************************/
    
    this ( ) { }
    
    /**************************************************************************
        
        Replaces each occurrence of "pattern" in the current content by
        "replacement". The content length is decreased or increased where
        appropriate.
        
        Params:
             content     = content to process
             pattern     = string pattern to replace
             replacement = replacement string
        
        Returns:
             the number of occurrences
             
     **************************************************************************/
    
    public size_t replacePattern ( ref T[] content, T[] pattern, T[] replacement )
    {
        return this.replace(content, pattern, replacement, false);
    }
    
    
    
    /**************************************************************************
        
        Replaces each occurrence of "chr" in the current content by "replacement".
        The content length is decreased or increased where appropriate.
        
        Params:
             content     = content to process
             chr         = character to replace
             replacement = replacement string
        
        Returns:
             the number of occurrences
             
     **************************************************************************/
    
    public size_t replaceChar ( ref T[] content, T[] pattern, T chr )
    {
        return this.replace(content, pattern, [chr], true);
    }

    
    
    /**************************************************************************
        
        Replaces each occurrence of any character of "charset" in the current
        content by "replacement". The content length is decreased or increased
        where appropriate.
        
        Params:
             content     = content to process
             charset     = set of characters to replace
             replacement = replacement string
        
        Returns:
             the number of occurrences
             
     **************************************************************************/
    
    public size_t replaceCharSet ( ref T[] content, T[] charset, T[] replacement )
    {
        return this.replace(content, charset, replacement, true);
    }
    
    
    
    /**************************************************************************
        
        Calls "decode" on each occurrence of "pattern" in the current content;
        "decode" shall then replace at most as many characters as the length of
        "pattern". The content length is decreased where appropriate.
        
        Params:
            content     = content to process
            pattern = search pattern
            decode  = delegate which replaces instances of "pattern"
            
        Returns:
            the number of occurrences
        
     **************************************************************************/
    
    public size_t replaceDecodePattern ( ref T[] content, T[] pattern, Decoder decode )
    {
        if (this.search(content, pattern, false))
        {
            this.replaceDecode(content, decode);
        }
        
        return this.items.length;
    }
    
    
    
    /**************************************************************************
        
        Calls "decode" on each occurrence of "chr" in the current content;
        "decode" shall then replace at most one character. The content length is
        decreased where appropriate.
        
        Params:
            content     = content to process
            pattern = set of characters to replace
            decode  = delegate which replaces instances of "pattern"
            
        Returns:
            the number of occurrences
        
     **************************************************************************/
    
    public size_t replaceDecodeChar ( ref T[] content, T chr, Decoder decode )
    {
        return this.replaceDecodeCharSet(content, [chr], decode);
    }
    
    
    
    /**************************************************************************
        
        Calls "decode" on each occurrence of any character of "charset" in
        the current content; "decode" shall then replace at most one character.
        The content length is decreased where appropriate.
        
        Params:
            content     = content to process
            pattern = set of characters to replace
            decode  = delegate which replaces instances of "pattern"
            
        Returns:
            the number of occurrences
        
     **************************************************************************/
    
   public size_t replaceDecodeCharSet ( ref T[] content, T[] charset, Decoder decode )
    {
        if (this.search(content, charset, true))
        {
            this.replaceDecode(content, decode);
        }
        
        return this.items.length;
    }
    
   /**************************************************************************
       
       Locates the next occurrence of any character in "charset" in "content",
       starting at index "start".
       
       Params:
           content = content to look for characters
           charset = set of characters to look for
           start   = start index for "content"
           
       Returns:
           the index of the next occurence of any character in "charset" in
           "content" or the length of "content" if nothing was found
           
    **************************************************************************/
   
    public static size_t locateCharSet ( ref T[] content, T[] charset, size_t start = 0 )
    {
        content ~= "\0";
        charset ~= "\0";
        
        scope (exit)
        {
            content.length = content.length - 1;
            charset.length = charset.length - 1;
        }
        
        return locateCharsZ(content, charset, start);
    }
    
    
    /**************************************************************************
        
        Shifts "length" characters inside "string" from "src_pos" to "dst_pos".
        This effectively does the same thing as
        
        ---
             string[src_pos .. src_pos + length] =  string[dst_pos .. dst_pos + length];
        ---
        
        but allows overlapping ranges.
        
        Params:
            str     = string to process
            dst_pos = destination start position (index) 
            src_pos = source start position (index)
            length  = number of array elements to shift
            
        Returns:
            resulting string
            
     **************************************************************************/
    
    public static T[] shiftString ( ref T[] str, size_t dst_pos, size_t src_pos, size_t length )
    {
        Wmemmove(str.ptr + dst_pos, str.ptr + src_pos, length);
        
        return str;
    }
    
    
    
    /**************************************************************************
        
        Copies "source" to "destin", starting at "dst_pos" of "destin".
        
        Params:
            destin  = destination string
            source  = source string
            dst_pos = start position (index) of destination
            
        Returns:
            resulting string
            
     **************************************************************************/
    
    public static T[] copyString ( ref T[] destin, T[] source, size_t dst_pos )
    in
    {
        assert (dst_pos + source.length <= destin.length,
                typeof (this).stringof ~ ".copyString(): destination string too short");
    }
    body
    {
        destin[dst_pos .. dst_pos + source.length] = source.dup;
        
        return destin;
    }

    
    /**************************************************************************
    
        Protected methods

     **************************************************************************/
    
    
    /**************************************************************************
        
        If "charset" is set to false, replaces each occurrence of "pattern" in
        "content" by "replacement". If "charset" is set to true, each occurrence
        of any character of "pattern" is replaced.
        The content length is decreased or increased where appropriate.
        
        Params:
            pattern     = search string or character set
            replacement = replace string
            charset     = set to false to replace each occurrence of "pattern" or
                          to true to replace each occurrence of any character in
                          "pattern".
                          
        Returns:
            the number of occurrences
            
     **************************************************************************/
    
    protected size_t replace ( ref T[] content, T[] pattern, T[] replacement, bool charset = false )
    {
        size_t pattern_length = charset? 1: pattern.length;
        
        if (this.search(content, pattern, charset))
        {
            if (replacement.length != pattern_length)
            {
                if (replacement.length > pattern_length)
                {
                    this.replaceGrow(content, replacement, pattern_length);
                }
                else
                {
                    this.replaceShrink(content, replacement, pattern_length);
                }
            }
            else
            {
                this.replaceEqual(content, replacement);
            }
        }
        
        return this.items.length;
    }
    
    
    
    /**************************************************************************
        
        If "charset" is set to false, searches for occurrences of "pattern" in
        "content" If "charset" is set to true, searches for occurrences
        of any character of "pattern".
        
        Params:
            content = content to search
            pattern = search string or character set
            charset = set to false to replace each occurrence of "pattern" or
                      to true to replace each occurrence of any character in
                      "pattern".
                          
        Returns:
            the number of occurrences
            
     **************************************************************************/
    
    protected size_t search ( T[] content, T[] pattern, bool charset = false )
    {
        size_t end = content.length;
        
        size_t function ( T[], T[], size_t ) locateZ = charset?
                                                           &locateCharsZ :
                                                           &locatePatternZ;
        
        this.addNullTerm(content);
        this.addNullTerm(pattern);
        
        scope (exit)
        {
            this.stripNullTerm(content);
            this.stripNullTerm(pattern);
        }
        
        this.items.length = 0;
        
        for (size_t item = locateZ(content, pattern, 0);
                    item < end;
                    item = locateZ(content, pattern, item + 1))
        {
            this.items ~= item;
        }
        
        return this.items.length;
    }
    
    
    
    /**************************************************************************
        
        Copies "replacement" to all positions in "string" given by "this.items".
        
        Params:
            content     = content with items to replace
            replacement = replace string
            
     **************************************************************************/
    
    protected void replaceEqual ( ref T[] content, T[] replacement )
    {
        foreach (item; this.items)
        {
            content[item .. item + replacement.length] = replacement;
        }
    }
    
    
    
    /**************************************************************************
        
        Replaces all slices of "content" which start with a position given by
        "this.items" and have a length of "search_length" by "replacement".
        The length of "replacement" is expected to be larger than
        "search_length", and the length of "input" is increased.
        
        Params:
            content       = content with items to replace
            replacement   = replace string
            search_length = length of the chunks to replace
            
     **************************************************************************/
    
    protected void replaceGrow ( ref T[] content, T[] replacement, size_t search_length )
    {
        assert (replacement.length > search_length, "StringReplace.replaceGrow: "
                                                    "replacement must be longer "
                                                    "than search pattern ");
        
        size_t d = replacement.length - search_length;
        
        size_t distance = (this.items.length * d);
        
        size_t next = content.length;
        
        content.length = content.length + distance;
        
        foreach_reverse (i, item; this.items)
        {
            distance -= d;
            
            size_t inter_length = next - item - search_length;
            
            this.shiftString(content, item + distance + replacement.length, item + search_length, inter_length);
            
            this.copyString(content, replacement, item + distance);
            
            next = item;
        }
    }

    
    
    /**************************************************************************
        
        Replaces all slices of "content" which start with a position given by
        "this.items" and have a length of "search_length" by "replacement".
        The length of "replacement" is expected to be smaller than
        "search_length", and the length of "input" is decreased.
        
        Params:
            content       = content with items to replace
            input         = input string
            replacement   = replace string
            search_length = length of the chunks to replace
            
     **************************************************************************/
    
    protected void replaceShrink ( ref T[] content, T[] replacement, size_t search_length )
    {
        assert (replacement.length < search_length, "StringReplace.replaceShrink: "
                                                    "replacement must be shorter "
                                                    "than search pattern ");
        
        size_t d = search_length - replacement.length;
        
        size_t distance = 0;
        
        size_t prev = this.items[0];

        this.items ~= content.length;
        
        foreach (i, item; this.items[1 .. $])
        {
            size_t inter_length = item - prev - search_length;
            
            this.copyString(content, replacement, prev - distance);
            
            this.shiftString(content, prev - distance + replacement.length, prev + search_length, inter_length);
            
            distance += d;
            
            prev = item;
        }
        
        content.length = content.length - distance;
    }
    
    
    
    
    /**************************************************************************
        
        Iterates over "this.items" and calls "decode" on each item; finally
        "content" is shortened by the number of characters replaced.
         
        Params:
            content = content to replace/decode
            decode  = Decode method as defined above:
                      ---
                         alias size_t delegate ( ref T[] input, size_t source_pos, size_t destin_pos ) Decoder;
                      ---
                      This method shall create one character from
                      the input string, starting from the current search pattern
                      occurence, and put the resulting character back to the
                      input string.
                      Params:
                          input  = input string
                          source = index of the first character of the  current
                                   search pattern occurrence
                          destin = index to put the resulting character
                      Shall return:
                          number of characters to remove from the input string
            
        Returns:
            the content after processing
            
     **************************************************************************/
    
    protected void replaceDecode ( ref T[] content, Decoder decode )
    {
        size_t distance = 0;
        
        size_t item = this.items[0];
        
        this.items ~= content.length;
        
        foreach (i, next; this.items[1 .. $])
        {
            size_t replaced = decode(content, item, item - distance); // invoke delegate
            
            size_t inter_length = next - item - replaced - 1;
            
            if (!replaced)  // move the character if nothing replaced
            {
                content[item - distance] = content[item];
            }
            
            this.shiftString(content, item - distance + 1, item + replaced + 1, inter_length);
            
            distance += replaced;
            
            item = next;
        }
        
        content.length = content.length - distance;
    }
    

    /**************************************************************************
    
        Private methods
    
     **************************************************************************/

    
    /**************************************************************************
        
        Locates the next occurrence of any character of "charset" in "content"
        starting from "start".
        
        Params:
            content = content to search
            charset = set of characters to search for
            start   = start index for "content"
            
        Returns:
            
     **************************************************************************/
    
    private static size_t locateCharsZ ( T[] content, T[] charset, size_t start = 0 )
    {
        return Wcscspn(content.ptr + start, charset.ptr) + start;
    }
    
    
    /**************************************************************************
        
        Locates the next occurrence of of "pattern" in "content" starting from
        "start".
        
        Params:
            content = content to search
            pattern = pattern to search for
            start   = start index for "content"
            
        Returns:
            
     **************************************************************************/
    
    private static size_t locatePatternZ ( T[] content, T[] pattern, size_t start = 0 )
    {
        return Wcsstr(content.ptr + start, pattern.ptr) - content.ptr;
    }
    
    
    
    /**************************************************************************
        
        Adds a '\0' terminator to "string" if none is present.
        
        Params:
             string = string to '\0'-terminate
            
        Returns:
             true if the string did not have a '\0'-terminator and therefore was
             changed, or false otherwise.
             
     **************************************************************************/
    
    private static bool addNullTerm ( ref T[] string )
    {
        bool term = string.length? !!string[$ - 1] : true;
        
        if (term)
        {
            string ~= "\0";
        }
        
        return term;
    }
    
    /**************************************************************************
        Strips the '\0' terminator from "string" if one is present.
        
        Params:
             string = string to strip
            
        Returns:
             true if the string had a '\0'-terminator and therefore was changed,
             or false otherwise.
     **************************************************************************/
    
    private static bool stripNullTerm ( ref T[] string )
    {
        bool strip = string.length? !string[$ - 1] : false;
        
        if (strip)
        {
            string.length = string.length - 1;
        }
        
        return strip;
    }
}
