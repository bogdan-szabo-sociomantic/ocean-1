/*******************************************************************************

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        Jan 2009: Initial release

    authors:        Thomas Nicolai, Lars Kirchhoff, Gavin Norman

    D Library Binding for PCRE regular expression engine.

    Requires linking with libpcre.

    Usage example:

    ---

        import ocean.text.regex.PCRE;

        auto pcre = new PCRE;

        // Simple, one-off use
        auto match = pcre.preg_match("Hello World!", "^Hello");

        // Compile then reuse
        auto regex = pcre.new CompiledRegex;
        regex.compile("^Hello");
        for ( int i; i < 100; i++ )
        {
            auto match = regex.match("Hello World!");
        }

    ---

    Related:

    http://regexkit.sourceforge.net/Documentation/pcre/pcreapi.html

*******************************************************************************/

module ocean.text.regex.PCRE;



/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array : copy, concat;
import ocean.text.util.StringC;
import ocean.text.regex.c.pcre;

import tango.stdc.stdlib : free;
import tango.text.convert.Format;



/*******************************************************************************

    PCRE

*******************************************************************************/

public class PCRE
{
    /***************************************************************************

        Represents a PCRE Exception.
        The class is re-usable exception where the error message can be
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

        String used internally for formatting.

    ***************************************************************************/

    private char[] buffer_char;

    /***************************************************************************

        A re-usable exception instance

    ***************************************************************************/

    private PcreException exception;

    /***************************************************************************

        Compiled regex class. Enables a regex pattern to be compiled once and
        used for multiple searches.

    ***************************************************************************/

    public class CompiledRegex
    {
        /***********************************************************************

            Pointer to C-allocated pcre regex object, created upon compilation
            of a regex (see compile()).

        ***********************************************************************/

        private pcre* pcre_object;

        /***********************************************************************

            Settings used by the call to pcre_exec() in the match() method.
            These are modified by the complexity_limit field of the outer class,
            and by the study() method.

        ***********************************************************************/

        private pcre_extra match_settings;

        /***********************************************************************

            Destructor. Frees the C-allocated pcre object.

        ***********************************************************************/

        ~this ( )
        {
            this.cleanup();
        }

        /***********************************************************************

            Compiles the specified regex for use in the match() method. Cleans
            up a previously compiled regex, if this instance has been used
            before.

            Params:
                pattern = pattern to search for, as a string
                case_sens = case sensitive matching

            Throws:
                if the compilation of the regex fails

            Out:
                following a call to this method, the compiled regex exists

        ***********************************************************************/

        public void compile ( char[] pattern, bool case_sens = true )
        out
        {
            assert(this.pcre_object);
        }
        body
        {
            this.cleanup();

            char* errmsg;
            int error_code;
            int error_offset;

            this.outer.buffer_char.concat(pattern, "\0");
            this.pcre_object = pcre_compile2(this.outer.buffer_char.ptr,
                    (case_sens ? 0 : PCRE_CASELESS), &error_code, &errmsg,
                    &error_offset, null);
            if ( !this.pcre_object )
            {
                this.outer.exception.msg.length = 0;
                Format.format(this.outer.exception.msg,
                    "Error compiling regular expression: {} - on pattern: {} at position {}",
                    StringC.toDString(errmsg), pattern, error_offset);
                this.outer.exception.error = error_code;
                throw this.outer.exception;
            }
        }

        /***********************************************************************

            Perform a regular expression match.

            Params:
                string  = input string

            Returns:
                true, if matches or false if no match

            Throws:
                if an error occurs when running the regex search

            In:
                the regex must have been compiled

        ***********************************************************************/

        public bool match ( char[] string )
        in
        {
            assert(this.pcre_object);
        }
        body
        {
            if ( this.outer.complexity_limit != DEFAULT_COMPLEXITY_LIMIT )
            {
                this.match_settings.flags |= PCRE_EXTRA_MATCH_LIMIT;
                this.match_settings.match_limit = this.outer.complexity_limit;
            }

            int error_code = pcre_exec(this.pcre_object, &this.match_settings,
                string.ptr, string.length, 0, 0, null, 0);
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

            In:
                the regex must have been compiled

        ***********************************************************************/

        public void study ( )
        in
        {
            assert(this.pcre_object);
        }
        body
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

        /***********************************************************************

            Cleans up the compiled regex object and the study data.

        ***********************************************************************/

        private void cleanup ( )
        {
            free(this.pcre_object);
            this.match_settings = this.match_settings.init;
        }
    }

    /***************************************************************************

        Constructor. Initializes the re-usable exception.

    ***************************************************************************/

    public this ( )
    {
        this.exception = new PcreException();
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
            case_sens = case sensitive matching

        Returns:
            true, if matches or false if no match

        Throws:
            if the compilation or running of the regex fails

    ***************************************************************************/

    public bool preg_match ( char[] string, char[] pattern, bool case_sens = true )
    {
        scope regex = new CompiledRegex;
        regex.compile(pattern, case_sens);
        return regex.match(string);
    }
}

version ( UnitTest )
{
    import ocean.core.Test;

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
                Format.format(test_name, "PCRE test #{}", ++test_num);
                matched = dg();
            }
            catch ( Exception e_ )
            {
                e = e_;
            }

            auto t = new NamedTest(test_name);

            t.test!("==")(error, e !is null);
            t.test!("==")(match, matched);
        }

        // This unittest tests only the interface of this method. It does not
        // test the full range of PCRE features as that is beyond its scope.
        auto pcre = new PCRE;

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

        // Case-sensitive match (fail)
        test({ return pcre.preg_match("Hello World", "hello"); }, false, false);

        // Case-insensitive match
        test({ return pcre.preg_match("Hello World", "hello", false); }, true, false);
    }
}

