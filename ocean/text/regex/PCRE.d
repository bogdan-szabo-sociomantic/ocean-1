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

private import ocean.core.Array : copy, concat;
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

            Error code returned by pcre function

        ***********************************************************************/

        public int error;

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

            Sets the error code and message.

            Params:
                code = error code to set
                msg = the new exception message to be used

        ***********************************************************************/

        private void set ( int code, char[] msg )
        {
            this.error = code;
            super.msg.copy(msg);
        }
    }

    /***************************************************************************

        A reusable char buffer

    ***************************************************************************/

    protected char[] buffer_char;

    /***************************************************************************

        A re-usable exception instance

    ***************************************************************************/

    protected PcreException exception;

    /***************************************************************************

        Compiled regex class. Enables a regex pattern to be compiled once and
        used for multiple searches. As this class is private, the only way to
        construct an instance is via the compile() method, below.

    ***************************************************************************/

    private class CompiledRegex
    {
        /***********************************************************************

            Pointer to C-allocated pcre object, created in ctor.

        ***********************************************************************/

        private const pcre* pcre_object;

        /***********************************************************************

            While this class instance exists, the pcre object must be non-null.

        ***********************************************************************/

        invariant
        {
            assert(this.pcre_object);
        }

        /***********************************************************************

            Constructor. Allocates the pcre object.

            Params:
                pattern = pattern to search for, as a string
                icase   = case sensitive matching

            Throws:
                if the compilation of the regex fails

        ***********************************************************************/

        public this ( char[] pattern, bool icase = false )
        {
            char* errmsg;
            int error_code;
            int error_offset;

            this.outer.buffer_char.concat(pattern, "\0");
            this.pcre_object = pcre_compile2(this.outer.buffer_char.ptr,
                    (icase ? PCRE_CASELESS : 0), &error_code, &errmsg,
                    &error_offset, null);
            if ( !this.pcre_object )
            {
                this.outer.exception.msg.length = 0;
                Layout!(char).print(this.outer.exception.msg,
                    "Error compiling regular expression: {} - on pattern: {} at position {}",
                    StringC.toDString(errmsg), pattern, error_offset);
                this.outer.exception.error = error_code;
                throw this.outer.exception;
            }
        }

        /***********************************************************************

            Destructor. Frees the C-allocated pcre object.

        ***********************************************************************/

        ~this ( )
        {
            free(this.pcre_object);
        }

        /***********************************************************************

            Perform a regular expression match.

            Params:
                string  = input string

            Returns:
                true, if matches or false if no match

            Throws:
                if an error occurs when running the regex search

        ***********************************************************************/

        public bool match ( char[] string )
        {
            this.outer.buffer_char.concat(string, "\0");
            int error_code = pcre_exec(this.pcre_object, null,
                this.outer.buffer_char.ptr, string.length, 0, 0, null, 0);
            if ( error_code >= 0 )
            {
                return true;
            }
            else if ( error_code != PCRE_ERROR_NOMATCH )
            {
                this.outer.exception.set(error_code,
                    "Error on executing regular expression!");
                throw this.outer.exception;
            }

            return false;
        }
    }

    /***************************************************************************

        constructor
        Initializes the re-usable exception.

    ***************************************************************************/

    public this()
    {
        this.exception = new PcreException();
    }

    /***************************************************************************

        Compiles a regex pattern and returns an instance of CompiledRegex, which
        can be used to perform multiple regex searches.

        Params:
            pattern = pattern to search for
            icase = case sensitive matching

        Returns:
            new CompiledRegex instance which can be used to perform multiple
            regex searches

        Throws:
            if the compilation of the regex fails

    ***************************************************************************/

    public CompiledRegex compile ( char[] pattern, bool icase = false )
    {
        return new CompiledRegex(pattern, icase);
    }


    /***************************************************************************

        Perform a regular expression match. Note that this method internally
        allocates and then frees a C pcre object each time it is called. If you
        want to run the same regex search multiple times on different input, you
        are probably better off using the compile() method, above.

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
        scope regex = new CompiledRegex(pattern, icase);
        return regex.match(string);
    }

    unittest
    {
        void test ( bool delegate ( ) dg, bool match, bool error )
        {
            static uint test_num;
            char[] test_name;
            Exception e;
            bool matched;
            try
            {
                Layout!(char).print(test_name, "PCRE test #{}", ++test_num);
                matched = dg();
            }
            catch ( Exception e_ )
            {
                e = e_;
            }
            assert(error == (e !is null),
                test_name ~ " exception " ~ (error ? "" : "not") ~ " expected");
            assert(match == matched,
                test_name ~ " match " ~ (match ? "" : "not") ~ " expected");
        }

        // This unittest tests only the interface of this method. It does not
        // test the full range of PCRE features as that is beyond its scope.
        auto pcre = new typeof(this);

        // Invalid pattern (error expected)
        test({ return pcre.preg_match("", "("); }, false, true);

        // Empty pattern (matches any string)
        test({ return pcre.preg_match("Hello World", ""); }, true, false);

        // Empty string and empty pattern (match)
        test({ return pcre.preg_match("", ""); }, true, false);

        // Empty string (no match)
        test({ return pcre.preg_match("", "a"); }, false, false);

        // Simple string match
        test({ return pcre.preg_match("Hello World", "Hello"); }, true, false);

        // Simple string match (fail)
        test({ return pcre.preg_match("Hello World", "Hallo"); }, false, false);

        // Case-sensitive match
        test({ return pcre.preg_match("Hello World", "Hello", true); }, true, false);

        // Case-sensitive match (fail)
        test({ return pcre.preg_match("Hello World", "hello", true); }, true, false);
    }
}
