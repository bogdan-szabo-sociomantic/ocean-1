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

private import tango.stdc.string: strdup, strlen, strncmp;
private import tango.stdc.posix.libgen: basename;
private import tango.stdc.posix.sys.time: gettimeofday, timeval, timersub;
private import tango.core.Runtime: Runtime;
private import tango.core.Exception : AssertException;
private import tango.io.Stdout: Stdout, Stderr;
private import tango.io.stream.Format: FormatOutput;
private import ocean.text.convert.Layout: Layout;

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
            Stdout.formatln("{}: unit tests started", this.prog);

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
                    Stdout.formatln("{}: {}: skipped (not in packages to test)",
                            this.prog, m.name);
                continue;
            }

            if (failed && !this.keep_going)
            {
                skipped++;
                if (this.verbose > 2)
                    Stdout.formatln("{}: {}: skipped (one failed and no "
                            "--keep-going)", this.prog, m.name);
                continue;
            }

            if (m.unitTest is null)
            {
                no_tests++;
                if (this.verbose > 1)
                    Stdout.formatln("{}: {}: skipped (no unittests)",
                            this.prog, m.name);
                continue;
            }

            if (this.verbose)
            {
                Stdout.format("{}: {}: testing ...", this.prog, m.name).flush();
            }

            // we have a unittest, run it
            timeval t;
            if (this.timedTest(m, t))
            {
                passed++;
                if (this.verbose)
                    Stdout.formatln(" PASSED [{}]", this.toHumanTime(t));
                continue;
            }

            failed++;
            if (this.verbose)
                Stdout.format(" FAILED [{}]", this.toHumanTime(t));

            if (!this.keep_going)
            {
                if (this.verbose)
                    Stdout.newline();
                continue;
            }

            if (this.verbose > 2)
                Stdout.formatln(" (continuing, --keep-going used)");
        }

        if (this.summary)
        {
            Stdout.format("{}: {} modules passed, {} failed, {} without "
                    "unittests", this.prog, passed, failed, no_tests);
            if (!this.keep_going && failed)
                Stdout.format(", {} skipped", skipped);
            if (this.verbose > 1)
                Stdout.format(", {} didn't match --package", no_match);
            Stdout.newline();
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
        char[] buff;
        if (tv.tv_sec >= 60*60)
            return Layout!(char).print(buff, "{:f1}h", tv.tv_sec / 60.0 / 60.0);

        if (tv.tv_sec >= 60)
            return Layout!(char).print(buff, "{:f1}m", tv.tv_sec / 60.0);

        if (tv.tv_sec > 0)
            return Layout!(char).print(buff, "{:f1}s",
                    tv.tv_sec + tv.tv_usec / 1_000_000.0);

        if (tv.tv_usec >= 1000)
            return Layout!(char).print(buff, "{:f1}ms", tv.tv_usec / 1_000.0);

        return Layout!(char).print(buff, "{}us", tv.tv_usec);
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
            Stderr.formatln("{}:{}: test error: {}", e.file, e.line, e.msg);
        }
        catch (AssertException e)
        {
            Stderr.formatln("{}:{}: assert error: {}", e.file, e.line, e.msg);
        }
        catch (Exception e)
        {
            Stderr.formatln("{}:{}: unexpected exception {}: {}",
                    e.file, e.line, e.classinfo.name, e.msg);
        }
        catch
        {
            Stderr.formatln("{}: unexpected unknown exception", m.name);
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
                this.printHelp(Stdout);
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
                    this.printUsage(Stderr);
                    Stderr.formatln("\n{}: error: missing argument for {}",
                            this.prog, arg);
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
            this.printUsage(Stderr);
            Stderr.format("\n{}: error: Unknown arguments:", this.prog);
            foreach (arg; unknown)
            {
                Stderr.format(" {}", arg);
            }
            Stderr.newline();
            return false;
        }

        return true;
    }


    /**************************************************************************

        Print the program's usage string.

        Params:
            fp = File pointer where to print the usage.

    ***************************************************************************/

    private void printUsage ( FormatOutput!(char) output )
    {
        output.formatln("Usage: {} [-h] [-v] [-s] [-k] [-p PKG]", this.prog);
    }


    /**************************************************************************

        Print the program's full help string.

        Params:
            fp = File pointer where to print the usage.

    ***************************************************************************/

    private void printHelp ( FormatOutput!(char) output )
    {
        this.printUsage(output);
        output.print(`
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

