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

private import tango.stdc.stdio: printf, fprintf, stdout, stderr, FILE;
private import tango.stdc.string: strdup, strlen;
private import tango.stdc.posix.libgen: basename;
private import tango.core.Runtime: Runtime;
private import tango.core.Exception : AssertException;

private import ocean.core.Test : TestException;



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
    private bool verbose = false;
    private bool summary = false;
    private bool keep_going = false;


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
            printf("%s: unittest started\n", this.prog.ptr);

        size_t passed = 0;
        size_t failed = 0;
        size_t skipped = 0;

        foreach ( m; ModuleInfo )
        {
            if (this.verbose)
            {
                printf("%s: %.*s: testing ...\n", this.prog.ptr,
                        m.name.length, m.name.ptr);
            }

            if (failed && !this.keep_going)
            {
                skipped++;
                if (this.verbose)
                    printf("%s: %.*s: skipped (one failed and no "
                            "--keep-going)\n", this.prog.ptr,
                            m.name.length, m.name.ptr);
                continue;
            }

            if (m.unitTest)
            {
                if (this.test(m))
                {
                    passed++;
                    if (this.verbose)
                        printf("%s: %.*s: PASSED\n", this.prog.ptr,
                                m.name.length, m.name.ptr);
                }
                else
                {
                    failed++;
                    if (this.verbose)
                        printf("%s: %.*s: FAILED", this.prog.ptr,
                                m.name.length, m.name.ptr);

                    if (this.keep_going)
                    {
                        if (this.verbose)
                            printf(" (continuing, --keep-going used)\n");
                    }
                    else
                    {
                        if (this.verbose)
                            printf("\n");
                    }
                }
            }
            else
            {
                skipped++;
                 if (this.verbose)
                    printf("%s: %.*s: skipped (no unittests)\n", this.prog.ptr,
                            m.name.length, m.name.ptr);
            }
        }

        if (this.summary)
            printf("%s: %zu passed, %zu skipped, %zu failed\n",
                    this.prog.ptr, passed, skipped, failed);

        if (failed)
            return 1;

        return 0;
    }


    /**************************************************************************

        Test a single module, catching and reporting any errors.

        Params:
            m = module to be tested

        Returns:
            true if the test passed, false otherwise.

    ***************************************************************************/

    private bool test ( ModuleInfo m )
    {
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

        foreach (arg; args[1..$])
        {
            switch (arg)
            {
            case "-h":
            case "--help":
                this.help = true;
                this.printHelp(stdout);
                return true;

            case "-v":
            case "--verbose":
                this.verbose = true;
                break;

            case "-s":
            case "--summary":
                this.summary = true;
                break;

            case "-k":
            case "--keep-going":
                this.keep_going = true;
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
        fprintf(stderr, "Usage: %s [-h] [-v] [-s] [-k]\n", this.prog.ptr);
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
  -v, --verbose     print more information about unittest progress
  -s, --summary     print a summary with the passed, skipped and failed number
                    of tests
  -k, --keep-going  don't stop after the first module unittest failed
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

