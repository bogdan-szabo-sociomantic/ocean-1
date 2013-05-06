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

private import ocean.core.Array : copy;
private import ocean.text.convert.Layout;
private import ocean.text.util.StringC;
private import ocean.text.regex.c.pcre;

private import tango.stdc.stdlib : free;


/*******************************************************************************

    PCRE

*******************************************************************************/

class PCRE
{
    /***************************************************************************

        Represents a PCRE Exception.
        The class is re-uusable exception where the error message can be
        reset and the same instance can be re-thrown.

    ***************************************************************************/

    public static class PcreException : Exception
    {
        /***********************************************************************

            Constructor.
            Just calls the super Exception constructor with initial error
            message.

        ***********************************************************************/

        public this()
        {
            super("Error message not yet set");
        }

        /***********************************************************************

            Sets the error message.

            Params:
                new_msg = the new exception message to be used

        ***********************************************************************/

        private void setMsg(char[] new_msg)
        {
            super.msg.length = 0;
            Layout!(char).print(super.msg, "{}", new_msg);
        }
    }

    /***************************************************************************

        A reusable char buffer

    ***************************************************************************/

    protected char[] buffer_char;

    /***************************************************************************

        A reusable int buffer

    ***************************************************************************/

    protected int[] buffer_int;

    /***************************************************************************

        A re-usable exception instance

    ***************************************************************************/

    protected PcreException exception;


    /***************************************************************************

        constructor
        Initializes the re-usable exception.

    ***************************************************************************/

    public this()
    {
        this.exception = new PcreException();
    }

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
        scope (exit) free(re);

        this.buffer_char.copy(pattern);
        if ((re = pcre_compile( StringC.toCstring(this.buffer_char),
                (icase ? PCRE_CASELESS : 0), &errmsg, &error, null)) == null)
        {
            this.buffer_char.length = 0;
            Layout!(char).print(this.buffer_char, "Couldn't compile regular "
                "expression: {} - on pattern: {}", StringC.toDString(errmsg),
                pattern);
            this.exception.setMsg(this.buffer_char);
            throw this.exception;
        }

        this.buffer_char.copy(string);
        if ((error = pcre_exec(re, null, StringC.toCstring(this.buffer_char),
                string.length, 0, 0, null, 0)) >= 0)
            return true;
        else if (error != PCRE_ERROR_NOMATCH)
        {
            this.exception.setMsg("Error on executing regular expression!");
            throw this.exception;
        }

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
        scope (exit) free(re);

        int*  ovector;

        this.buffer_char.copy(pattern);
        if ((re = pcre_compile(StringC.toCstring(this.buffer_char),
                (icase ? PCRE_CASELESS : 0), &errmsg, &error, null)) == null)
        {
            this.buffer_char.length = 0;
            Layout!(char).print(this.buffer_char, "Couldn't compile regular "
                "expression: {} - on pattern: {}", StringC.toDString(errmsg),
                pattern);
            this.exception.setMsg(this.buffer_char);
            throw this.exception;
        }

        if ( pcre_fullinfo(re, null, PCRE_INFO_CAPTURECOUNT, &ovector_length) < 0 )
        {
            this.exception.setMsg("Internal pcre_fullinfo() error");
            throw this.exception;
        }

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
            {
                this.exception.setMsg("Error on executing regular expression!");
                throw this.exception;
            }

            start_offset = cast(int) ovector[1];
        }
        while ( count > 0 );

        return num_matches;
    }
}
