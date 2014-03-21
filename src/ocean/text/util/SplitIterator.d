/******************************************************************************

    String splitting utilities

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        February 2011: Initial release

    author:         David Eckardt

    - The SplitStr class splits a string by occurrences of a delimiter string.
    - The SplitChr class splits a string by occurrences of a delimiter
      character.

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

/*
 * SearchFruct in tango.text.Search is declared private but that protection
 * attribute is meaningless. Ticket is submitted.
 * @see http://www.dsource.org/projects/tango/ticket/2102
 * @see http://www.digitalmars.com/webnews/newsgroups.php?art_group=digitalmars.D&article_id=87915
 */

private import tango.text.Search: SearchFruct, search;

/******************************************************************************

    Splits a string by occurrences of a delimiter string.

    Memory friendly, suitable for stack-allocated scope instances.

 ******************************************************************************/

class StrSplitIterator : ISplitIterator
{
    /**************************************************************************

        Contains the delimiter as match string and manages a table of indices to
        improve the search algorithm efficiency. May be modified at any time
        using its methods.

     **************************************************************************/

    public const SearchFruct!(char) sf;

    /**************************************************************************

        Constructor

        Params:
            delim_ = delimiter string

     **************************************************************************/

    public this ( char[] delim_ )
    {
        this.sf = .search(delim_);
    }

    /**************************************************************************

        Constructor

        Intended to be used for a 'scope' instance where a SearchFruct instance
        is stored somewhere in order to reuse the search index.

        Params:
            delim = delimiter string

     **************************************************************************/

    public this ( SearchFruct!(char) sf_in )
    {
        this.sf = sf_in;
    }

    /**************************************************************************

        Old constructor

     **************************************************************************/

    deprecated public this ( ) {this (this.sf.init);}

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
    {
        this.sf.match = delim_;

        return delim_;
    }

    /**************************************************************************

        Returns:
            current delimiter string (without NUL-terminator; slices an internal
            buffer)

     **************************************************************************/

    public char[] delim ( )
    {
        return this.sf.match;
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
        return this.sf.forward(str, start);
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
    {
        assert (str.length >= this.delim.length);

        return this.sf.match.length;
    }

    /**************************************************************************/

    unittest
    {
        scope split = new typeof (this)("123");

        split.collapse = true;

        foreach (str; ["123""ab""123"     "cd""123""efg""123",
                       "123""ab""123""123""cd""123""efg""123",
                       "123""ab""123""123""cd""123""efg",
                            "ab""123""123""cd""123""efg",

                       "123""123""ab""123""123""cd""123""efg",
                       "ab""123""123""cd""123""efg""123""123"])
        {
            foreach (element; split.reset(str))
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

        split.reset("ab""123""cd""123""efg");

        assert (split.next == "ab");
        assert (split.next == "cd");
        assert (split.next == "efg");
    }
}

/******************************************************************************

    Splits a string by occurrences of a delimiter character

 ******************************************************************************/

class ChrSplitIterator : ISplitIterator
{
    /**************************************************************************

        Delimiter character. Must be specified in the constructor but may be
        changed at any time, even during iteration.

     **************************************************************************/

    public char delim;

    /**************************************************************************

        Constructor

        Params:
            delim_ = delimiter character

     **************************************************************************/

    public this ( char delim_ )
    {
        this.delim = delim_;
    }

    /**************************************************************************

        Old constructor

     **************************************************************************/

    deprecated public this ( ) { }

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

        Union of the supported 'foreach' iteration delegate types

     **************************************************************************/

    protected union IterationDelegate
    {
        int delegate ( ref size_t pos, ref char[] segment ) with_pos;

        int delegate ( ref char[] segment ) without_pos;
    }

    /**************************************************************************

        Consistency check

     **************************************************************************/

    invariant ( )
    {
        if (this.n_)
        {
            assert (this.content);
        }

        /*
         * TODO: Is this what
         * ---
         * assert (this.content[$ - this.remaining_.length .. $] is this.remaining_);
         * ---
         * does, that is, comparing the memory location for identity, not the
         * content? If so, replace it.
         */

        assert (this.remaining_.length <= this.content.length);

        if (this.remaining_.length)
        {
            assert (this.remaining_.ptr is &this.content[$ - this.remaining_.length]);
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

        segment slices content so do not modify it. However, the content of
        segment may be modified which will result in an in-place modification
        of the content.

     **************************************************************************/

    public int opApply ( int delegate ( ref char[] segment ) dg_in )
    {
        IterationDelegate dg;

        dg.without_pos = dg_in;

        return this.opApply_(false, dg);
    }

    /**************************************************************************

        'foreach' iteration over string slices between the current and the next
        delimiter. n() returns the number of 'foreach' loop cycles so far,
        remaining() the slice after the next delimiter to the content end.
        If no delimiter was found, n() is 0 after 'foreach' has finished and
        remaining() returns the content.

        pos references the current content position and may be changed to
        specify the position where searching should be continued. If changed,
        pos must be at most content.length.

        segment slices content so do not modify it. However, the content of
        segment may be modified which will result in an in-place modification
        of the content.

     **************************************************************************/

    public int opApply ( int delegate ( ref size_t pos, ref char[] segment ) dg_in )
    {
        IterationDelegate dg;

        dg.with_pos = dg_in;

        return this.opApply_(true, dg);
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

        Locates the first delimiter occurrence in the current content string
        starting from content[start].

        Params:
            start = start index, must be at most content.length

        Returns:
            index of the first delimiter occurrence in str or str.length
            either not found or start >= content.length

         In:
             start must be at most content.length.

     **************************************************************************/

    public size_t locateDelim ( size_t start = 0 )
    in
    {
        assert (start <= this.content.length,
                typeof (this).stringof ~ ".locateDelim(): start index out of range");
    }
    body
    {
        return this.locateDelim(this.content, start);
    }

    /**************************************************************************

        Skips initial consecutive occurrences of the current delimiter in the
        currently remaining content.

        Returns:
             remaining content after the delimiters have been skipped.

     **************************************************************************/

    public char[] skipLeadingDelims ( )
    {
        size_t start = 0,
               pos   = this.locateDelim(this.remaining_);

        while (pos == start && pos < this.remaining_.length)
        {
            start = pos + this.skipDelim(this.remaining_[pos .. $]);

            pos = this.locateDelim(this.remaining_, start);
        }

        return this.remaining_ = this.remaining_[start .. $];
    }

    /**************************************************************************

        Searches the next delimiter.

        Returns:
            a slice to the content between the previous and next delimiter, if
            found. If not found and include_remaining is true, the remaining
            content is returned or null if include_remaining is false.

     **************************************************************************/

    public char[] next ( )
    {
        if (this.remaining_.length)
        {
            this.n_++;

            if (this.collapse)
            {
                this.skipLeadingDelims();
            }

            size_t start = this.content.length - this.remaining_.length,
                   end   = this.locateDelim(start);

            if (end < this.content.length)
            {
                this.remaining_ = this.content[end + this.skipDelim(this.content[end .. $]) .. $];

                return this.content[start .. end];
            }
            else if (this.include_remaining)
            {
                scope (success) this.remaining_ = null;

                return this.remaining_;
            }
            else
            {
                return null;
            }
        }
        else
        {
            return null;
        }
    }

    /**************************************************************************

        'foreach' iteration over string slices between the current and the next
        delimiter.

        Params:
            with_pos = true: use dg.with_pos, false: user dg.without_pos
            dg       = iteration delegate

        Returns:
            passes through dg() return value.

     **************************************************************************/

    protected int opApply_ ( bool with_pos, IterationDelegate dg )
    {
        int result = 0;

        if (this.remaining_.length)
        {
            if (this.collapse)
            {
                this.skipLeadingDelims();
            }

            size_t start = this.content.length - this.remaining_.length;

            for (size_t pos = this.locateDelim(start);
                        pos < this.content.length;
                        pos = this.locateDelim(start))
            {
                size_t next = pos + this.skipDelim(this.content[pos .. $]);

                if (!(pos == start && collapse))
                {
                    this.n_++;

                    char[] segment  = this.content[start ..  pos];
                    this.remaining_ = this.content[next .. $];

                    if (with_pos)
                    {
                        result = dg.with_pos(next, segment);

                        assert (next <= this.content.length,
                                typeof (this).stringof ~ ": iteration delegate "
                                "set the position out of range");

                        this.remaining_ = this.content[next .. $];
                    }
                    else
                    {
                        result = dg.without_pos(segment);
                    }
                }

                start = next;

                if (result || start >= this.content.length) break;
            }

            this.remaining_ = this.content[start .. $];

            if (this.include_remaining &&
                !(result || (!this.remaining_.length && this.collapse)))
            {
                this.n_++;

                char[] segment = this.remaining_;

                this.remaining_ = "";

                result = with_pos? dg.with_pos(start, segment) :
                                   dg.without_pos(segment);
            }
        }

        return result;
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