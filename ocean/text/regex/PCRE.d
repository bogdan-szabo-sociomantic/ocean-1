/*******************************************************************************

        copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

        version:        Jan 2009: Initial release

        authors:        Thomas Nicolai, Lars Kirchhoff

        D Library Binding for PCRE regular expression engine

        This module provides bindings for the libpcre library. This is just a
        first draft and needs further extension.

        Be aware that you have to pass the D parser the path to the
        libpcre library. If you use DSSS you have to add the buildfalgs option
        to your dsss.conf e.g.

        buildflags=-L/usr/lib/libpcre.so

        You'll need to ensure that the libpcre.so is located under the /usr/lib
        directory.

        --

        Usage example:

            auto regex = new PCRE;

            if ( regex.preg_match("Hello World!", "^Hello") == true)
                Stdout("match");
            else
                Stdout("no match");

        --

        TODO:

            Implement preg_replace()
            Implement preg_split()


        Related:

        http://regexpal.com/
        http://www.pcre.org/
        http://www.pcre.org/pcre.txt
        http://de2.php.net/manual/en/ref.pcre.php


*******************************************************************************/

module  ocean.text.PCRE;

public  import ocean.core.Exception: PCREException;

private import ocean.text.regex.c.pcre;

private import tango.stdc.stringz : toDString = fromStringz, toCString = toStringz;


/*******************************************************************************

    PCRE

*******************************************************************************/

class PCRE
{

    /**
     * Only use methods static
     *
     */
    public this () {}



    /**
     * Perform a regular expression match
     *
     * ---
     * Usage:
     *
     *      auto regex = new PCRE;
     *
     *      bool match = regex.preg_match("Hello World!", "^Hello");
     *
     * ---
     *
     * Params:
     *     string  = input string (subject)
     *     pattern = pattern to search for, as a string
     *     icase   = case sensitive matching
     *
     * Returns:
     *     true, if matches or false if no match
     */
    public bool preg_match ( char[] string, char[] pattern, bool icase = false )
    {
        char* errmsg;
        int error;
        pcre* re;

        if ((re = pcre_compile(toCString(pattern), (icase ? PCRE_CASELESS : 0), &errmsg, &error, null)) == null)
            PCREException("Couldn't compile regular expression: " ~ toDString(errmsg) ~ " on pattern: " ~ pattern);

        if ( (error = pcre_exec(re, null, toCString(string), string.length, 0, 0, null, 0)) >= 0)
            return true;
        else if (error != PCRE_ERROR_NOMATCH)
            PCREException("Error on executing regular expression!");

        return false;
    }



    /**
     * Perform a global regular expression match
     *
     * ---
     *
     * Usage:
     *
     *      char[][][] matches;
     *
     *      auto regex = new PCRE;
     *
     *      char[] preg = "Hello";
     *      char[] subj = "Hello World Hello Word";
     *
     *      int i = regex.preg_match_all(subj, preg, matches);
     *
     *      foreach ( match; matches )
     *      {
     *          foreach ( element; match )
     *              Stdout.format("{}", element);
     *
     *          Stdout.newline();
     *      }
     *
     * ---
     *
     * Params:
     *     string  = input string (subject)
     *     pattern = pattern to search for, as a string
     *     matches = array to store matches into
     *     icase   = case sensitive matching
     *
     * Returns:
     *     zero, or number of matches
     */
    public int preg_match_all ( char[] string, char[] pattern, inout char[][][] matches, bool icase = false )
    {
        int   error, count, num_matches, start_offset, ovector_length;
        char* errmsg, stringptr;
        pcre* re;

        int*  ovector;
        int[] x;

        if ((re = pcre_compile(toCString(pattern), (icase ? PCRE_CASELESS : 0), &errmsg, &error, null)) == null)
            PCREException("Couldn't compile regular expression: " ~ toDString(errmsg) ~ " on pattern: " ~ pattern);

        if ( pcre_fullinfo(re, null, PCRE_INFO_CAPTURECOUNT, &ovector_length) < 0 )
            PCREException("Internal pcre_fullinfo() error");

        ovector_length = (ovector_length + 1) * 3;
        x.length = ovector_length;
        ovector = x.ptr;

        do
        {
            count = pcre_exec(re, null, toCString(string), string.length, start_offset, 0, ovector, ovector_length);

            if ( count > 0 )
            {
                char[][] match_item;

                ++num_matches;

                for ( int i = 0; i < count; i++ )
                {
                    pcre_get_substring(toCString(string), ovector, count, i, &stringptr);
                    match_item ~= toDString(stringptr).dup;
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



    /**
     * Search and replace a regular expression match
     *
     * Params:
     *     pattern  =
     *     replacement =
     *     subject   =
     *     limit =
     *     count =
     *
     * Returns:
     *     array of strings or null on error
     */
    public char[] preg_replace ( char[][] pattern, char[][] replacement, char[] subject, int limit = 10, int count = 10 )
    {
        return null;
    }



    /**
     * Split string by regular expression match
     *
     * Params:
     *     string  =
     *     pattern =
     *     icase   =
     *
     * Returns:
     *     array of strings or null on error
     */
    public char[][] preg_split ( char[] pattern, char[] subject, int limit, int flags )
    {
        return null;
    }



}
