module text.StringReplace;

private import tango.stdc.stddef: wchar_t;
private import tango.stdc.string: memmove, wmemmove,
                                  strstr,  wcsstr,
                                  strcspn, wcscspn;

private import tango.io.Stdout;

class StringReplace ( T )
{
    /**************************************************************************

        Aliases

     **************************************************************************/
    
    
    /**
     * Aliases for byte/wide character C string functions.
     * 
     * wchar_t is an alias of dchar or wchar, depending on platform; see
     * tango.stdc.stddef
     */
    static if (is (T == char))
    {
        private alias memmove Wmemmove;
        private alias strstr  Wcsstr;
        private alias strcspn Wcscspn;
    }
    else
    {
        static assert (is (T == wchar_t), "ExtUtil: type '" ~ T.stringof ~
                                          "' not supported; please use '" ~
                                          wchar_t.stringof ~ "'");
        private alias wmemmove Wmemmove;
        private alias wcsstr   Wcsstr;
        private alias wcscspn  Wcscspn;
    }
    
    
    
    /**
     * Decoder delegate signature for replaceDecode functions.
     */
    alias uint delegate ( ref T[] input, uint source_pos, uint destin_pos ) Decoder;
    
    
    /**************************************************************************

        Properties

     **************************************************************************/
    
    
    /**
     * List of search pattern/characters occurrences found.
     */
    private uint[] items;
    
    
    /**************************************************************************
    
        Public class methods
    
     **************************************************************************/

    
    /**
     * Constructor: nothing to do
     */
    this ( ) { }
    
    
    
    /**
     * Replaces each occurrence of "pattern" in the actual content by
     * "replacement". The content length is decreased or increased where
     * appropriate.
     * 
     * Params:
     *      content     = content to process
     *      pattern     = string pattern to replace
     *      replacement = replacement string
     * 
     * Returns:
     *      the number of occurrences
     */
    public uint replacePattern ( ref T[] content, T[] pattern, T[] replacement )
    {
        return this.replace(content, pattern, replacement, false);
    }
    
    
    
    /**
     * Replaces each occurrence of "chr" in the actual content by "replacement".
     * The content length is decreased or increased where appropriate.
     * 
     * Params:
     *      content     = content to process
     *      chr         = character to replace
     *      replacement = replacement string
     * 
     * Returns:
     *      the number of occurrences
     */
    public uint replaceChar ( ref T[] content, T[] pattern, T chr )
    {
        return this.replace(content, pattern, [chr], true);
    }

    
    
    /**
     * Replaces each occurrence of any character of "charset" in the actual
     * content by "replacement". The content length is decreased or increased
     * where appropriate.
     * 
     * Params:
     *      content     = content to process
     *      charset     = set of characters to replace
     *      replacement = replacement string
     * 
     * Returns:
     *      the number of occurrences
     */
    public uint replaceCharSet ( ref T[] content, T[] charset, T[] replacement )
    {
        return this.replace(content, charset, replacement, true);
    }
    
    
    
    /**
     * Calls "decode" on each occurrence of "pattern" in the actual content;
     * "decode" shall then replace at most as many characters as the length of
     * "pattern". The content length is decreased where appropriate.
     * 
     * Params:
     *     content     = content to process
     *     pattern = search pattern
     *     decode  = delegate which replaces instances of "pattern"
     * Returns:
     */
    public uint replaceDecodePattern ( ref T[] content, T[] pattern, Decoder decode )
    {
        if (this.search(content, pattern, false))
        {
            this.replaceDecode(content, decode);
        }
        
        return this.items.length;
    }
    
    
    
    /**
     * Calls "decode" on each occurrence of "chr" in the actual content;
     * "decode" shall then replace at most one character. The content length is
     * decreased where appropriate.
     * 
     * Params:
     *     content     = content to process
     *     pattern = set of characters to replace
     *     decode  = delegate which replaces instances of "pattern"
     * Returns:
     */
    public uint replaceDecodeChar ( ref T[] content, T chr, Decoder decode )
    {
        return this.replaceDecodeCharSet(content, [chr], decode);
    }
    
    
    
    /**
     * Calls "decode" on each occurrence of any character of "charset" in
     * the actual content; "decode" shall then replace at most one character.
     * The content length is decreased where appropriate.
     * 
     * Params:
     *     content     = content to process
     *     pattern = set of characters to replace
     *     decode  = delegate which replaces instances of "pattern"
     * Returns:
     */
   public uint replaceDecodeCharSet ( ref T[] content, T[] charset, Decoder decode )
    {
        if (this.search(content, charset, true))
        {
            this.replaceDecode(content, decode);
        }
        
        return this.items.length;
    }
    
   
   /**************************************************************************
   
       Public utility methods

    **************************************************************************/
   
    
   /**
    * Locates the next occurrence of any character in "charset" in "content",
    * starting at index "start".
    * 
    * Params:
    *     content = content to look for characters
    *     charset = set of characters to look for
    *     start   = start index for "content"
    *     
    * Returns:
    *     the index of the next occurence of any character in "charset" in
    *     "content" or the length of "content" if nothing was found
    */
    public static uint locateCharSet ( ref T[] content, T[] charset, uint start = 0 )
    {
        content  ~= "\0";
        charset ~= "\0";
        
        scope (exit)
        {
            content.length  = content.length - 1;
            charset.length = charset.length - 1;
        }
        
        return locateCharsZ(content, charset, start);
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
    public static void shiftString ( ref T[] string, uint dst_pos, uint src_pos, uint length )
    {
        Wmemmove(string.ptr + dst_pos, string.ptr + src_pos, length);
    }
    
    
    
    /**
     * Copies "source" to "destin", starting at "dst_pos" of "destin".
     * 
     * Params:
     *     destin  = destination string
     *     source  = source string
     *     dst_pos = start position (index) of destination
     */
    public static void copyString ( ref T[] destin, T[] source, uint dst_pos )
    {
        assert (dst_pos + source.length <= content.length, "Encode.copyString: "
                                                           "destination string "
                                                           "too short");
        
        string[dst_pos .. dst_pos + source.length] = source.dup;
    }

    
    /**************************************************************************
    
        Protected methods

     **************************************************************************/
    
    
    /**
     * If "charset" is set to false, replaces each occurrence of "pattern" in
     * "content" by "replacement". If "charset" is set to true, each
     * occurrence of any character of "pattern" is replaced.
     * The content length is decreased or increased where appropriate.
     * 
     * Params:
     *     pattern     = search string or character set
     *     replacement = replace string
     *     charset     = set to false to replace each occurrence of "pattern" or
     *                   to true to replace each occurrence of any character in
     *                   "pattern".
     *                   
     * Returns:
     *     the number of occurrences
     */
    protected uint replace ( ref T[] content, T[] pattern, T[] replacement, bool charset = false )
    {
        uint pattern_length = charset? 1: pattern.length;
        
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
    
    
    
    /**
     * If "charset" is set to false, searches for occurrences of "pattern" in
     * "content" If "charset" is set to true, searches for occurrences
     * of any character of "pattern".
     * 
     * Params:
     *     content = content to search
     *     pattern = search string or character set
     *     charset = set to false to replace each occurrence of "pattern" or
     *               to true to replace each occurrence of any character in
     *               "pattern".
     *                   
     * Returns:
     *     the number of occurrences
     */
    protected uint search ( T[] content, T[] pattern, bool charset = false )
    {
        uint end = content.length;
        
        uint function ( T[], T[], uint ) locateZ = charset?
                                                   &locateCharsZ  :
                                                   &locatePatternZ;
        
        this.addNullTerm(content);
        this.addNullTerm(pattern);
        
        scope (exit)
        {
            this.stripNullTerm(content);
            this.stripNullTerm(pattern);
        }
        
        this.items.length = 0;
        
        for (uint item = locateZ(content, pattern, 0);
                  item < end;
                  item = locateZ(content, pattern, item + 1))
        {
            this.items ~= item;
        }
        
        return this.items.length;
    }
    
    
    
    /**
     * Copies "replacement" to all positions in "string" given by "this.items".
     * 
     * Params:
     *     content     = content with items to replace
     *     replacement = replace string
     */
    protected void replaceEqual ( ref T[] content, T[] replacement )
    {
        foreach (item; this.items)
        {
            content[item .. item + replacement.length] = replacement;
        }
    }
    
    
    
    /**
     * Replaces all slices of "content" which start with a position given by
     * "this.items" and have a length of "search_length" by "replacement".
     * The length of "replacement" is expected to be larger than
     * "search_length", and the length of "input" is increased.
     * 
     * Params:
     *     content       = content with items to replace
     *     replacement   = replace string
     *     search_length = length of the chunks to replace
     *     
     */
    protected void replaceGrow ( ref T[] content, T[] replacement, uint search_length )
    {
        assert (replacement.length > search_length, "StringReplace.replaceGrow: "
                                                    "replacement must be longer "
                                                    "than search pattern ");
        
        uint d = replacement.length - search_length;
        
        uint distance = (this.items.length * d);
        
        uint next = content.length;
        
        content.length = content.length + distance;
        
        foreach_reverse (i, item; this.items)
        {
            distance -= d;
            
            uint inter_length = next - item - search_length;
            
            this.shiftString(content, item + distance + replacement.length, item + search_length, inter_length);
            
            this.copyString(content, replacement, item + distance);
            
            next = item;
        }
    }

    
    
    /**
     * Replaces all slices of "content" which start with a position given by
     * "this.items" and have a length of "search_length" by "replacement".
     * The length of "replacement" is expected to be smaller than
     * "search_length", and the length of "input" is decreased.
     * 
     * Params:
     *     content       = content with items to replace
     *     input         = input string
     *     replacement   = replace string
     *     search_length = length of the chunks to replace
     *     
     */
    protected void replaceShrink ( ref T[] content, T[] replacement, uint search_length )
    {
        assert (replacement.length < search_length, "StringReplace.replaceShrink: "
                                                    "replacement must be shorter "
                                                    "than search pattern ");
        
        uint d = search_length - replacement.length;
        
        uint distance = 0;
        
        uint prev = this.items[0];

        this.items ~= content.length;
        
        foreach (item; this.items[1 .. $])
        {
            uint inter_length = item - prev - search_length;
            
            this.copyString(content, replacement, prev - distance);
            
            this.shiftString(content, prev - distance + replacement.length, prev + search_length, inter_length);
            
            distance += d;
            
            prev = item;
        }
        
        content.length = content.length - distance;
    }
    
    
    
    
    /**
     * Iterates over "this.items" and calls "decode" on each item; finally
     * "content" is shortened by the number of characters replaced.
     *  
     * Params:
     *     content = content to replace/decode
     *     decode  = Decode method as defined above:
     *               ---
     *                  alias uint delegate ( ref T[] input, uint source_pos, uint destin_pos ) Decoder;
     *               ---
     *               This method shall create one character from
     *               the input string, starting from the actual search pattern
     *               occurence, and put the resulting character back to the
     *               input string.
     *               Params:
     *                   input  = input string
     *                   source = index of the first character of the  actual
     *                            search pattern occurrence
     *                   destin = index to put the resulting character
     *               Shall return:
     *                   number of characters to remove from the input string
     *     
     * Returns:
     *     the content after processing
     */
    protected void replaceDecode ( ref T[] content, Decoder decode )
    {
        uint distance = 0;
        
        uint item = this.items[0];
        
        this.items ~= content.length;
        
        foreach (i, next; this.items[1 .. $])
        {
            uint replaced = decode(content, item, item - distance); // invoke delegate
            
            uint inter_length = next - item - replaced - 1;
            
            if (!replaced) // move the character if nothing replaced
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

    
    /**
     * Locates the next occurrence of any character of "charset" in "content"
     * starting from "start".
     * 
     * Params:
     *     content = content to search
     *     charset = set of characters to search for
     *     start   = start index for "content"
     *     
     * Returns:
     *     
     */
    private static uint locateCharsZ ( T[] content, T[] charset, uint start = 0 )
    {
        return Wcscspn(content.ptr + start, charset.ptr) + start;
    }
    
    
    /**
     * Locates the next occurrence of of "pattern" in "content" starting from
     * "start".
     * 
     * Params:
     *     content = content to search
     *     pattern = pattern to search for
     *     start   = start index for "content"
     *     
     * Returns:
     *     
     */
    private static uint locatePatternZ ( T[] content, T[] pattern, uint start = 0 )
    {
        return Wcsstr(content.ptr + start, pattern.ptr) - content.ptr;
    }
    
    
    
    /**
     * Adds a '\0' terminator to "string" if none is present.
     * 
     * Params:
     *      string = string to '\0'-terminate
     *     
     * Returns:
     *      true if the string did not have a '\0'-terminator and therefore was
     *      changed, or false otherwise.
     */
    private static bool addNullTerm ( ref T[] string )
    {
        bool term = string.length? !!string[$ - 1] : true;
        
        if (term)
        {
            string ~= "\0";
        }
        
        return term;
    }
    
    
    
    /**
     * Strips the '\0' terminator from "string" if one is present.
     * 
     * Params:
     *      string = string to strip
     *     
     * Returns:
     *      true if the string had a '\0'-terminator and therefore was changed,
     *      or false otherwise.
     */
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
