/******************************************************************************

    Flexible unittest runner

    copyright:      Copyright (c) 2014 Sociomantic Labs. All rights reserved

    This module provides a more flexible unittest runner.

    The goals for this test runner is to function as a standalone program,
    instead of being run before another program's main(), as is common in D.

    To achieve this, the main() function is provided by this module too.

    To use it, just import this module and any other module you want to test,
    for example:

    ---
    module tester;
    import ocean.core.UnitTestRunner;
    import mymodule;
    ---

    That's it. Compile with: dmd -unittest tester.d mymodule.d

    You can control the unittest execution, try ./tester -h for help on the
    available options.

*******************************************************************************/

module ocean.core.UnitTestRunner;


/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.stdc.stdio: snprintf, printf, fprintf, fflush,
                                 stdout, stderr, FILE;
private import tango.stdc.string: strdup, strlen, strncmp;
private import tango.stdc.posix.libgen: basename;
private import tango.stdc.posix.sys.time: gettimeofday, timeval, timersub;
private import tango.core.Runtime: Runtime;
private import tango.core.Exception : AssertException;

private import ocean.core.Test : TestException, test;



/******************************************************************************

    Handle all the details about unittest execution.

******************************************************************************/

private scope class UnitTestRunner
{

    /**************************************************************************

        Options parsed from the command-line

    ***************************************************************************/

    private char[] prog;
    private bool help = false;
    private size_t verbose = 0;
    private bool summary = false;
    private bool keep_going = false;
    private char[][] packages = null;


    /**************************************************************************

        Static constructor replacing the default Tango unittest runner

    ***************************************************************************/

    static this ( )
    {
        Runtime.moduleUnitTester(&this.dummyUnitTestRunner);
    }

    /**************************************************************************

        Dummy unittest runner.

        This runner does nothing because we handle all the unittest execution
        directly in the main() function, so we can parse the program's argument
        before running the unittests.

        Returns:
            true to tell the runtime we want to run main()

    ***************************************************************************/

    private static bool dummyUnitTestRunner()
    {
        return true;
    }


    /**************************************************************************

        Run all the unittest registered by the runtime.

        The parseArgs() function must be called before this method.

        Returns:
            exit status to pass to the operating system.

    ***************************************************************************/

    private int run ( )
    {
        assert (prog);

        if (this.verbose)
            printf("%s: unit tests started\n", this.prog.ptr);

        size_t passed = 0;
        size_t failed = 0;
        size_t skipped = 0;
        size_t no_tests = 0;
        size_t no_match = 0;

        foreach ( m; ModuleInfo )
        {
            if (!this.shouldTest(m.name))
            {
                no_match++;
                if (this.verbose > 1)
                    printf("%s: %.*s: skipped (not in packages to test)\n",
                            this.prog.ptr, m.name.length, m.name.ptr);
                continue;
            }

            if (failed && !this.keep_going)
            {
                skipped++;
                if (this.verbose > 2)
                    printf("%s: %.*s: skipped (one failed and no "
                            "--keep-going)\n", this.prog.ptr,
                            m.name.length, m.name.ptr);
                continue;
            }

            if (m.unitTest is null)
            {
                no_tests++;
                if (this.verbose > 1)
                    printf("%s: %.*s: skipped (no unittests)\n", this.prog.ptr,
                            m.name.length, m.name.ptr);
                continue;
            }

            if (this.verbose)
            {
                printf("%s: %.*s: testing ...", this.prog.ptr,
                        m.name.length, m.name.ptr);
                fflush(stdout);
            }

            // we have a unittest, run it
            timeval t;
            bool success = this.timedTest(m, t);
            auto elapsed = this.toHumanTime(t);
            if (success)
            {
                passed++;
                if (this.verbose)
                    printf(" PASSED [%.*s]\n", elapsed.length, elapsed.ptr);
                continue;
            }

            failed++;
            if (this.verbose)
                printf(" FAILED [%.*s]", elapsed.length, elapsed.ptr);

            if (!this.keep_going)
            {
                if (this.verbose)
                    printf("\n");
            }

            if (this.verbose > 2)
                printf(" (continuing, --keep-going used)\n");
        }

        if (this.summary)
        {
            printf("%s: %zu modules passed, %zu failed, %zu without unittests",
                    this.prog.ptr, passed, failed, no_tests);
            if (!this.keep_going && failed)
                printf(", %zu skipped", skipped);
            if (this.verbose > 1)
                printf(", %zu didn't match --package", no_match);
            printf("\n");
        }

        if (failed)
            return 1;

        return 0;
    }


    /**************************************************************************

        Convert a timeval to a human readable string.

        If it is in the order of hours, then "N.Nh" is used, if is in the order
        of minutes, then "N.Nm" is used, and so on for seconds ("s" suffix),
        milliseconds ("ms" suffix) and microseconds ("us" suffix).

        Params:
            tv = timeval to print

        Returns:
            string with the human readable form of tv.

    ***************************************************************************/

    private static char[] toHumanTime ( timeval tv )
    {
        char[] toFloatString ( double val, double divisor, char[] fmt )
        {
            auto b = new char[256];
            auto n = val / divisor;
            int format() { return snprintf(b.ptr, b.length, fmt, n); }
            auto len = format();
            if (len >= b.length)
            {
                b.length = len;
                len = format();
                assert (len < b.length);
            }
            return b[0 .. len];
        }

        if (tv.tv_sec >= 60*60)
            return toFloatString(tv.tv_sec, 60*60, "%.1fh");

        if (tv.tv_sec >= 60)
            return toFloatString(tv.tv_sec, 60, "%.1fm");

        if (tv.tv_sec > 0)
            return toFloatString(tv.tv_sec + tv.tv_usec / 1_000_000.0, 1,
                        "%.1fs");

        if (tv.tv_usec >= 1000)
            return toFloatString(tv.tv_usec, 1_000, "%.1fms");

        return toFloatString(tv.tv_usec, 1, "%.0fus");
    }

    unittest
    {
        timeval tv;
        test!("==")(toHumanTime(tv), "0us");
        tv.tv_sec = 1;
        test!("==")(toHumanTime(tv), "1.0s");
        tv.tv_sec = 1;
        test!("==")(toHumanTime(tv), "1.0s");
        tv.tv_usec = 100_000;
        test!("==")(toHumanTime(tv), "1.1s");
        tv.tv_usec = 561_235;
        test!("==")(toHumanTime(tv), "1.6s");
        tv.tv_sec = 60;
        test!("==")(toHumanTime(tv), "1.0m");
        tv.tv_sec = 61;
        test!("==")(toHumanTime(tv), "1.0m");
        tv.tv_sec = 66;
        test!("==")(toHumanTime(tv), "1.1m");
        tv.tv_sec = 60*60;
        test!("==")(toHumanTime(tv), "1.0h");
        tv.tv_sec += 10;
        test!("==")(toHumanTime(tv), "1.0h");
        tv.tv_sec += 6*60;
        test!("==")(toHumanTime(tv), "1.1h");
        tv.tv_sec = 0;
        test!("==")(toHumanTime(tv), "561.2ms");
        tv.tv_usec = 1_235;
        test!("==")(toHumanTime(tv), "1.2ms");
        tv.tv_usec = 1_000;
        test!("==")(toHumanTime(tv), "1.0ms");
        tv.tv_usec = 235;
        test!("==")(toHumanTime(tv), "235us");
    }

    /**************************************************************************

        Test a single module, catching and reporting any errors.

        Params:
            m = module to be tested

        Returns:
            true if the test passed, false otherwise.

    ***************************************************************************/

    private bool timedTest ( ModuleInfo m, out timeval tv )
    {
        timeval start;
        int e = 0;
        e = gettimeofday(&start, null);
        assert (e == 0, "gettimeofday returned != 0");

        scope (exit)
        {
            timeval end;
            e = gettimeofday(&end, null);
            assert (e == 0, "gettimeofday returned != 0");
            timersub(&end, &start, &tv);
        }

        try
        {
            m.unitTest();
            return true;
        }
        catch (TestException e)
        {
            fprintf(stderr, "%.*s:%zu: test error: %.*s\n",
                    e.file.length, e.file.ptr, e.line, e.msg.length, e.msg.ptr);
        }
        catch (AssertException e)
        {
            fprintf(stderr, "%.*s:%zu: assert error: %.*s\n",
                    e.file.length, e.file.ptr, e.line, e.msg.length, e.msg.ptr);
        }
        catch (Exception e)
        {
            fprintf(stderr, "%.*s:%zu: unexpected exception %.*s: %.*s\n",
                    e.file.length, e.file.ptr, e.line,
                    e.classinfo.name.length, e.classinfo.name.ptr,
                    e.msg.length, e.msg.ptr);
        }
        catch
        {
            fprintf(stderr, "%.*s: unexpected unknown exception\n",
                    m.name.length, m.name.ptr);
        }

        return false;
    }


    /**************************************************************************

        Check if a module with name `name` should be tested.

        Params:
            name = Name of the module to check if it should be tested.

        Returns:
            true if it should be tested, false otherwise.

    ***************************************************************************/

    bool shouldTest ( char[] name )
    {
        // No packages specified, matches all
        if (this.packages.length == 0)
            return true;

        foreach (pkg; this.packages)
        {
            if (name.length >= pkg.length &&
                    strncmp(pkg.ptr, name.ptr, pkg.length) == 0)
                return true;
        }

        return false;
    }


    /**************************************************************************

        Parse command line arguments filling the internal options and program
        name.

        This function also print help and error messages.

        Params:
            args = command line arguments as received by main()

        Returns:
            true if the arguments are OK, false otherwise.

    ***************************************************************************/

    private bool parseArgs ( char[][] args )
    {
        // we don't care about freeing anything, is just a few bytes and the program
        // will quite after we are done using these variables
        char* bin_c = strdup(args[0].ptr);
        char* prog_c = basename(bin_c);
        this.prog = prog_c[0..strlen(prog_c)];

        char[][] unknown;

        bool skip_next = false;

        args = args[1..$];

        foreach (i, arg; args)
        {
            if (skip_next)
            {
                skip_next = false;
                continue;
            }

            switch (arg)
            {
            case "-h":
            case "--help":
                this.help = true;
                this.printHelp(stdout);
                return true;

            case "-vvv":
                this.verbose++;
                goto case;
            case "-vv":
                this.verbose++;
                goto case;
            case "-v":
            case "--verbose":
                this.verbose++;
                break;

            case "-s":
            case "--summary":
                this.summary = true;
                break;

            case "-k":
            case "--keep-going":
                this.keep_going = true;
                break;

            case "-p":
            case "--package":
                if (args.length <= i+1)
                {
                    this.printUsage(stderr);
                    fprintf(stderr, "\n%s: error: missing argument for %.*s\n",
                            this.prog.ptr, arg.length, arg.ptr);
                    return false;
                }
                this.packages ~= args[i+1];
                skip_next = true;
                break;

            default:
                unknown ~= arg;
                break;
            }
        }

        if (unknown.length)
        {
            this.printUsage(stderr);
            fprintf(stderr, "\n%s: error: Unknown arguments:", this.prog.ptr);
            foreach (arg; unknown)
            {
                fprintf(stderr, " %s", arg.ptr);
            }
            fprintf(stderr, "\n");
            return false;
        }

        return true;
    }


    /**************************************************************************

        Print the program's usage string.

        Params:
            fp = File pointer where to print the usage.

    ***************************************************************************/

    private void printUsage ( FILE* fp )
    {
        fprintf(stderr, "Usage: %s [-h] [-v] [-s] [-k] [-p PKG]\n",
                this.prog.ptr);
    }


    /**************************************************************************

        Print the program's full help string.

        Params:
            fp = File pointer where to print the usage.

    ***************************************************************************/

    private void printHelp ( FILE* fp )
    {
        this.printUsage(fp);
        fprintf(fp, `
optional arguments:
  -h, --help        print this message and exit
  -v, --verbose     print more information about unittest progress, can be
                    specified multiple times (even as -vvv, 3 is the maximum),
                    the first level only prints the executed tests, the second
                    level print the tests skipped because there are no unit
                    tests in the module or because it doesn't match the -p
                    patterns, and the third level print also tests skipped
                    because no -k is used and a test failed
  -s, --summary     print a summary with the passed, skipped and failed number
                    of tests
  -k, --keep-going  don't stop after the first module unittest failed
  -p, --package PKG
                    only run tests in the PKG package (effectively any module
                    which fully qualified name starts with PKG), can be
                    specified multiple times to indicate more packages to test
`);
    }
}



/******************************************************************************

    Main function that run all the modules unittests using UnitTestRunner.

******************************************************************************/

int main(char[][] args)
{
    scope runner = new UnitTestRunner;

    auto args_ok = runner.parseArgs(args);

    if (runner.help)
        return 0;

    if (!args_ok)
        return 2;

    return runner.run();
}

