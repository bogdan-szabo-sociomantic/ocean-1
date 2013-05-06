/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D Library Binding for PCRE regular expression engine

        This module provides bindings for the libpcre library. This is just a
        first draft and needs further extension.

        Requires linking with libpcre

        Usage example:

            auto regex = new PCRE;

            if ( regex.preg_match("Hello World!", "^Hello") == true)
                Stdout("match");
            else
                Stdout("no match");

        Related:

        http://regexpal.com/
        http://www.pcre.org/
        http://www.pcre.org/pcre.txt
        http://de2.php.net/manual/en/ref.pcre.php


*******************************************************************************/

module  ocean.text.regex.PCRE;

/*******************************************************************************

    Imports

*******************************************************************************/
public  import ocean.core.Exception: PCREException;

private import ocean.core.Array : copy;
private import ocean.text.convert.Layout;
private import ocean.text.util.StringC;
private import ocean.text.regex.c.pcre;



/*******************************************************************************

    PCRE

*******************************************************************************/

class PCRE
{
    /***************************************************************************

        A reusable char buffer

    ***************************************************************************/

    protected char[] buffer_char;

    /***************************************************************************

        A reusable int buffer

    ***************************************************************************/

    protected int[] buffer_int;


    /***************************************************************************

        Perform a regular expression match


        Usage:
            auto regex = new PCRE;
            bool match = regex.preg_match("Hello World!", "^Hello");

        Params:
            string  = input string (subject)
            pattern = pattern to search for, as a string
            icase   = case sensitive matching

        Returns:
            true, if matches or false if no match

    ***************************************************************************/

    public bool preg_match ( char[] string, char[] pattern, bool icase = false )
    {
        char* errmsg;
        int error;
        pcre* re;

        this.buffer_char.copy(pattern);
        if ((re = pcre_compile( StringC.toCstring(this.buffer_char),
                (icase ? PCRE_CASELESS : 0), &errmsg, &error, null)) == null)
            PCREException("Couldn't compile regular expression: " ~ StringC.toDString(errmsg) ~ " on pattern: " ~ pattern);


        this.buffer_char.copy(string);
        if ((error = pcre_exec(re, null, StringC.toCstring(this.buffer_char),
                string.length, 0, 0, null, 0)) >= 0)
            return true;
        else if (error != PCRE_ERROR_NOMATCH)
            PCREException("Error on executing regular expression!");

        return false;
    }



    /***************************************************************************

        Perform a global regular expression match

        FIXME:
            THe method wasn't recently tested for functionality correctness or
            for effecient memory usage (due to absence of a test example).
            The user should test both the functionality and memory usage of the
            method before using it.

        Usage:

            char[][][] matches;

            auto regex = new PCRE;

            char[] preg = "Hello";
            char[] subj = "Hello World Hello Word";

            int i = regex.preg_match_all(subj, preg, matches);

            foreach ( match; matches )
            {
                foreach ( element; match )
                    Stdout.format("{}", element);

                Stdout.newline();
            }

        Params:
            string  = input string (subject)
            pattern = pattern to search for, as a string
            matches = array to store matches into
            icase   = case sensitive matching

        Returns:
            zero, or number of matches

    ***************************************************************************/

    public int preg_match_all ( char[] string, char[] pattern, inout char[][][] matches, bool icase = false )
    {
        int   error, count, num_matches, start_offset, ovector_length;
        char* errmsg, stringptr;
        pcre* re;

        int*  ovector;

        this.buffer_char.copy(pattern);
        if ((re = pcre_compile(StringC.toCstring(this.buffer_char),
                (icase ? PCRE_CASELESS : 0), &errmsg, &error, null)) == null)
            PCREException("Couldn't compile regular expression: " ~ StringC.toDString(errmsg) ~ " on pattern: " ~ pattern);

        if ( pcre_fullinfo(re, null, PCRE_INFO_CAPTURECOUNT, &ovector_length) < 0 )
            PCREException("Internal pcre_fullinfo() error");

        ovector_length = (ovector_length + 1) * 3;
        this.buffer_int.length = ovector_length;
        ovector = this.buffer_int.ptr;

        do
        {
            this.buffer_char.copy(string);
            count = pcre_exec(re, null, StringC.toCstring(this.buffer_char),
                string.length, start_offset, 0, ovector, ovector_length);

            if ( count > 0 )
            {
                char[][] match_item;

                ++num_matches;

                for ( int i = 0; i < count; i++ )
                {
                    pcre_get_substring(StringC.toCstring(this.buffer_char),
                        ovector, count, i, &stringptr);
                    match_item ~= StringC.toDString(stringptr).dup;
                    pcre_free_substring(stringptr);
                }

                matches ~= match_item;
            }
            else if (count != PCRE_ERROR_NOMATCH)
                PCREException("Error on executing regular expression!");

            start_offset = cast(int) ovector[1];
        }
        while ( count > 0 );

        return num_matches;
    }
}
