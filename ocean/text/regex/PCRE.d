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

        Limits the complexity of regex searches. If a regex search passes the
        specified complexity limit without either finding a match or determining
        that no match exists, it bails out, throwing an exception (see
        CompiledRegex.match()).

        The default value of 0 uses libpcre's built-in default complexity
        limit (10 million, see below), which is set to be extremely permissive.
        Any value less than 10 million will have the effect of reducing the
        level of complexity tolerated, thus reducing the potential processing
        time spent searching.

        This field maps directly to the match_limit field in libpcre's
        pcre_extra struct.

        From http://regexkit.sourceforge.net/Documentation/pcre/pcreapi.html:

        The match_limit field provides a means of preventing PCRE from using up
        a vast amount of resources when running patterns that are not going to
        match, but which have a very large number of possibilities in their
        search trees. The classic example is the use of nested unlimited
        repeats.

        Internally, PCRE uses a function called match() which it calls
        repeatedly (sometimes recursively). The limit set by match_limit is
        imposed on the number of times this function is called during a match,
        which has the effect of limiting the amount of backtracking that can
        take place. For patterns that are not anchored, the count restarts from
        zero for each position in the subject string.

        The default value for the limit can be set when PCRE is built; the
        default default is 10 million, which handles all but the most extreme
        cases.

    ***************************************************************************/

    public const int DEFAULT_COMPLEXITY_LIMIT = 0;

    public int complexity_limit = DEFAULT_COMPLEXITY_LIMIT;

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

            Settings used by the call to pcre_exec() in the match() method.
            These are modified by the complexity_limit field of the outer class,
            and by the study() method.

        ***********************************************************************/

        private pcre_extra match_settings;


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
            if ( this.outer.complexity_limit != DEFAULT_COMPLEXITY_LIMIT )
            {
                this.match_settings.flags |= PCRE_EXTRA_MATCH_LIMIT;
                this.match_settings.match_limit = this.outer.complexity_limit;
            }

            this.outer.buffer_char.concat(string, "\0");
            int error_code = pcre_exec(this.pcre_object, &this.match_settings,
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

        /***********************************************************************

            Study a compiled regex in order to increase processing efficiency
            when calling match(). This is usually only worth doing for a regex
            which will be used many times, and does not always yield an
            improvement in efficiency.

            Throws:
                if an error occurs when studying the regex

        ***********************************************************************/

        public void study ( )
        {
            char* errmsg;
            auto res = pcre_study(this.pcre_object, 0, &errmsg);
            if ( errmsg )
            {
                this.outer.exception.set(0, StringC.toDString(errmsg));
                throw this.outer.exception;
            }
            if ( res )
            {
                this.match_settings.study_data = res.study_data;
            }
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

        Throws:
            if the compilation or running of the regex fails

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
