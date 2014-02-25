/******************************************************************************

    String search and replace methods

    --

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

        StringReplace!() replace = new StringReplace!();

        // fill "content" with text

        replace.replacePattern(content, "Max", "Moritz");

        // all occurrences of "Max" in "content" are now replaced by "Moritz"

    ---

 ******************************************************************************/

module ocean.text.util.StringReplace;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.text.util.StringSearch;

private import ocean.text.convert.Layout;

/******************************************************************************

    StringReplace class

 ******************************************************************************/

class StringReplace ( bool wide_char = false )
{
    /**************************************************************************

        Template instance alias

     **************************************************************************/

    private alias StringSearch!(wide_char) StringSearch_;

    /**************************************************************************

        Character type alias

     **************************************************************************/

    public  alias StringSearch_.Char              Char;

    /**************************************************************************

        Decoder delegate signature for replaceDecode functions.

     **************************************************************************/

    public alias size_t delegate ( Char[] pattern, ref Char[] replacement ) Decoder;


    /**************************************************************************

        List of search pattern/characters occurrences found.

     **************************************************************************/

    private size_t[] items;

    private Char[] replacement;

    /**************************************************************************

        A re-usable buffer to use with the Layout formatter in the
        replacePatternLayout method.

     **************************************************************************/

    private char[] buf;

    /**************************************************************************

        Default length of occurrence items list

     **************************************************************************/

    static const DefaultItemsLength = 0x1000;

    /**************************************************************************

         Constructor

         Params:
             inital_items = initial length of occurrence items list

     **************************************************************************/

    public this ( size_t inital_items = DefaultItemsLength )
    {
        this.items = new size_t[inital_items];
    }

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

    public size_t replacePattern ( ref Char[] content, Char[] pattern, Char[] replacement )
    {
        return this.replace(content, pattern, replacement, false);
    }


    /**************************************************************************

        The method will accept any aribtary replacement pattern and will pass it
        through the Layout formatter.  The resulting string will replace
        any occurrance of the target pattern. The content length is decreased or
        increased where appropriate.

        Params:
             content     = content to process
             pattern     = string pattern to replace
             replacement = replacement object

        Returns:
             the number of occurrences

     **************************************************************************/

    public size_t replacePatternLayout(T) ( ref Char[] content, Char[] pattern,
            T replacement )
    {
        this.buf.length = 0;
        Layout!(char).print(this.buf, "{}", replacement );
        return this.replacePattern(content, pattern, this.buf);
    }


    /**************************************************************************

        Replaces each occurrence of chr in content by replacement. The content
        length is decreased or increased where appropriate.

        Params:
             content     = content to process
             chr         = character to replace
             replacement = replacement string

        Returns:
             the number of occurrences

     **************************************************************************/

    public size_t replaceChar ( ref Char[] content, Char chr, Char[] replacement )
    {
        return this.replace(content, [chr], replacement, true);
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

    public size_t replaceCharSet ( ref Char[] content, Char[] charset, Char[] replacement )
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

    public size_t replaceDecodePattern ( ref Char[] content, Char[] pattern, Decoder decode )
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

    public size_t replaceDecodeChar ( ref Char[] content, Char chr, Decoder decode )
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

   public size_t replaceDecodeCharSet ( ref Char[] content, Char[] charset, Decoder decode )
    {
        if (this.search(content, charset, true))
        {
            this.replaceDecode(content, decode);
        }

        return this.items.length;
    }

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

    protected size_t replace ( ref Char[] content, Char[] pattern, Char[] replacement, bool charset = false )
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

    protected size_t search ( Char[] content, Char[] pattern, bool charset = false )
    {
        size_t end = content.length;

        size_t function ( Char[], Char[], size_t ) locateZ = charset?
                                                           &locateCharsZ :
                                                           &locatePatternZ;

        StringSearch_.appendTerm(content);
        StringSearch_.appendTerm(pattern);

        scope (exit)
        {
            StringSearch_.stripTerm(content);
            StringSearch_.stripTerm(pattern);
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

    protected void replaceEqual ( ref Char[] content, Char[] replacement )
    {
        foreach (item; this.items)
        {
            content[item .. item + replacement.length] = replacement.dup;
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

    protected void replaceGrow ( ref Char[] content, Char[] replacement, size_t search_length )
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

            StringSearch_.shiftString(content, item + distance + replacement.length, item + search_length, inter_length);

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

    protected void replaceShrink ( ref Char[] content, Char[] replacement, size_t search_length )
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

            StringSearch_.shiftString(content, prev - distance + replacement.length, prev + search_length, inter_length);

            distance += d;

            prev = item;
        }

        content.length = content.length - distance;
    }



    /**************************************************************************

        Iterates over "this.items" and calls "decode" on each item; finally
        "content" is shortened by the number of removed characters.

        Params:
            content = content to replace/decode
            decode  = Decode callback method as defined above:
                      ---
                         alias size_t delegate ( Char[] content, out Char[] replacement ) Decoder;
                      ---
                      On invocation, the content starting from the current
                      search pattern occurrence in is passed to the callback
                      method. The method shall then decide how many characters
                      to replace, put a replacement string to replacement and
                      return the number of characters to be replaced.
                      The length of the replacement string must equal or be less
                      than the number of characters replaced.

                      Params:
                          content     = content starting with current search
                                        pattern occurrence
                          replacement = replacement pattern output

                      Shall return:
                          number of characters replaced by replacement pattern

     **************************************************************************/

    protected void replaceDecode ( ref Char[] content, Decoder decode )
    {
        size_t distance = 0;

        auto item = this.items[0];

        this.items ~= content.length;

        foreach (i, next; this.items[1 .. $])
        {
            auto dst_pos      = item - distance;

            this.replacement.length = 0;

            auto replaced     = decode(content[item .. $], this.replacement); // invoke delegate

            auto len          = this.replacement.length;

            auto inter_length = next - item - replaced;

            assert (len <= replaced,                      "StringReplace: replacement exceeds replaced pattern");
            assert (dst_pos + replaced <= content.length, "StringReplace: replaced string exceeds content");
            assert (replaced           <= next - item,    "StringReplace: replaced string hits next occurrence");

            content[dst_pos .. dst_pos + len] = this.replacement[];

            StringSearch_.shiftString(content, item - distance + len, item + replaced, inter_length);

            distance += replaced - len;

            item = next;
        }

        content.length = content.length - distance;
    }

    /**************************************************************************

        Locates the next occurrence of any character of "charset" in "content"
        starting from "start".

        Params:
            content = content to search
            charset = set of characters to search for
            start   = start index for "content"

        Returns:
            index of next occurrence

     **************************************************************************/

    private static size_t locateCharsZ ( Char[] content, Char[] charset, size_t start = 0 )
    {
        return StringSearch_.pLocateFirstInSet(content.ptr + start, charset.ptr) + start;
    }


    /**************************************************************************

        Locates the next occurrence of of "pattern" in "content" starting from
        "start".

        Params:
            content = content to search
            pattern = pattern to search for
            start   = start index for "content"

        Returns:
            index of next occurrence

     **************************************************************************/

    private static size_t locatePatternZ ( Char[] content, Char[] pattern, size_t start = 0 )
    {
        return StringSearch_.pLocatePattern(content.ptr + start, pattern.ptr) - content.ptr;
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

    private static Char[] copyString ( ref Char[] destin, Char[] source, size_t dst_pos )
    in
    {
        assert (dst_pos + source.length <= destin.length,
                typeof (this).stringof ~ ".copyString(): destination string too short");
    }
    body
    {
        destin[dst_pos .. dst_pos + source.length] = source;

        return destin;
    }

    /**************************************************************************

        Destructor

     **************************************************************************/

    private ~this ( )
    {
        delete this.items;
    }
}
