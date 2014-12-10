/*******************************************************************************

    Unittest class

    copyright:      Copyright (c) 2009-2011 sociomantic labs.
                    All rights reserved

    version:        October 2011: initial release

    authors:        Mathias L. Baumann

*******************************************************************************/

module ocean.util.Unittest;



/*******************************************************************************

    Imports

*******************************************************************************/


import Integer = tango.text.convert.Integer;

import tango.util.log.AppendConsole;

import tango.util.log.Log;

import tango.io.Stdout;

import tango.text.convert.Format;

/*******************************************************************************

    Base failed unittest exception class. Used to differentiate between
    test check failures and internal application exceptions that happen during
    testing if this becomes necessary.

*******************************************************************************/

deprecated
class TestException : Exception
{
    /***************************************************************************

        Test case name (if any)

    ***************************************************************************/

    private char[] name;

    /***************************************************************************

        Wraps Exception constructor.

    ***************************************************************************/

    deprecated public this ( char[] name, char[] msg, char[] file, size_t line )
    {
        super( msg, file, line );
        this.name = name;
    }

    /***************************************************************************

        Default formatter

    ***************************************************************************/

    deprecated public override char[] toString()
    {
        return Format(
            "{}:{} : Test '{}' has failed ({})",
            this.file,
            this.line,
            this.name,
            this.msg
        );
    }
}

/*******************************************************************************

    Unittest scope class

    Helper class to enable the possibility to run all unittests, not just
    all till one fails. Stores file name to avoid duplication, assigns names
    to tests.

    Also provides `enforce` and `enforceRel` utility methods which do throw
    immediately as built-in assert does but do better message formatting.

    Usage Example
    --------
    import ocean.util.Unittest;
    import tango.io.Stdout;

    unittest
    {
        static bool throwing()
        {
            throw new Exception("oops");
        }

        {
            scope t = new Unittest(__FILE__, "ExampleTest");
            with (t)
            {
                assertLog( 1 == 2, __LINE__);
                assertLog( throwing(), "Math failed", __LINE__);
                assertLog( 1 == 1, "Basic logic failed", __LINE__);
            }
        }

        try
        {
            scope t = new Unittest(__FILE__, "Throwing Example", false);
            with (t)
            {
               enforceRel!("==")(2, 3, __LINE__);
            }
        }
        catch (TestException e)
        {
            Stdout.formatln("{}", e);
        }
    }

    void main ( )
    {
        Unittest.check();  // Required call
    }

    -------
    This example would output:

    example.d:15 : Assertion failed
    Caught exception while executing assert check: :0 oops
    example.d:16 : Assertion failed (Math failed)
    Test ExampleTest failed
    example.d:26 : Test 'Throwing Example' has failed (Expression '2 == 3' evaluates to false)
    terminated after throwing an uncaught instance of 'object.Exception'
      toString():  2 of 2 Unittests failed!

*******************************************************************************/

deprecated
scope class Unittest
{
    /***************************************************************************

        Amount of unittests and how many of them failed

    ***************************************************************************/

    static private size_t num_failed, num_all;

    /***************************************************************************

        Name and file of the test

    ***************************************************************************/

    private char[] name, file;

    /***************************************************************************

        Whether this test failed

    ***************************************************************************/

    private bool failed = false;

    /***************************************************************************

        If set to true, summary message is printed for a test case block if any
        single test has failed.

    ***************************************************************************/

    private bool summary = true;

    /***************************************************************************

        Whether any test failed

        Params:
            throw_ = if true, will throw any exception, else false

        Returns:
            true when no test failed, else false

    ***************************************************************************/

    deprecated public static bool check ( bool throw_ = true )
    {
        if ( num_failed > 0 )
        {
            if ( throw_ ) throw new Exception(Integer.toString(num_failed) ~
                                              " of " ~ Integer.toString(num_all) ~
                                              " Unittests failed!");

            return false;
        }

        return true;
    }

    /***************************************************************************

        Constructor

        Params:
            file = file of the unittest
            test = name of the test
            summary = activates printing of failure state upon unittest block
                disposal

    ***************************************************************************/

    deprecated public this ( char[] file, char[] name, bool summary = true )
    {
        Unittest.num_all++;

        this.name = name;
        this.file = file;
        this.summary = summary;
    }

    /***************************************************************************

        Destructor

        If the test failed, the failed counter is being increased

    ***************************************************************************/

    ~this ( )
    {
        if ( failed )
        {
            Unittest.num_failed++;
        }

        Log.root.clear();
    }

    /***************************************************************************

        Assert method that logs any error with the given line

        Params:
            ok   = true: the assert was satisfied, false the assert was unhappy
            line = line at which the assert happened

    ***************************************************************************/

    deprecated public void assertLog ( lazy bool ok, size_t line )
    {
        this.assertLog(ok, null, line );
    }

    /***************************************************************************

        Assert method that logs any error with the given line

        Params:
            ok   = true: the assert was satisfied, false the assert was unhappy
            msg  = description of the assert
            line = line at which the assert happened

    ***************************************************************************/

    deprecated public void assertLog ( lazy bool ok, char[] msg = null, size_t line = 0 )
    {
        void print ()
        {
            char[] fmsg = msg;

            if (msg !is null)
            {
                fmsg = " (" ~ msg ~ ")";
            }

            if ( line > 0 )
            {
                Stderr.formatln("{}:{} : Assertion failed{}", this.file, line, fmsg);
            }
            else
            {
                Stderr.formatln("{} : Assertion failed{}", this.file, fmsg);
            }
        }

        try if ( ok == false )
        {
            this.failed = true;

            print();
        }
        catch ( Exception e )
        {
            this.failed = true;

            Stderr.formatln("Caught exception while executing assert check: {}:{} {}",
                            e.file, e.line, e.msg);
            print();
        }
    }

    /***************************************************************************

        Similar to built-in assert, stops the test case early by throwing
        exception. Should be used for checks critical for testing integrity.

        Params:
            ok = boolean expression to check
            msg = error message to put into exception
            line = line of origin

        Throws:
            TestException if !ok

    ***************************************************************************/

    deprecated public void enforce (T) ( T ok, char[] msg = "", size_t line = 0 )
    {
        if (!ok)
        {
            Unittest.num_failed++;
            throw new TestException(this.name, msg, this.file, line);
        }
    }

    /***************************************************************************

        Similar to built-in assert, stops the test case early by throwing
        exception. This overload allows for test checks with line but no message,
        which is useful when doing lot of similar checks in cluster.

        Params:
            ok = boolean expression to check
            line = line of origin

        Throws:
            TestException if !ok

    ***************************************************************************/

    deprecated public void enforce (T) ( T ok, size_t line )
    {
        this.enforce(ok, "", line);
    }

    /***************************************************************************

        Short form for 'enforce relation'. Similar to `enforce` but takes
        a comparison operator as template parameter string and both operands
        as separate parameters. Upon a failure detailed error message is
        generated.

        Template params:
            op = string representation of binary comparison operator, e.g. "=="

        Params:
            exp1 = left side of comparison expression
            exp2 = right side of comparison expression
            line = line of origin

        Throws:
            TestException if expression evaluates to false

    ***************************************************************************/

    deprecated public void enforceRel ( char[] op, T1, T2 ) ( T1 exp1, T2 exp2, size_t line )
    {
        mixin ("bool ok = exp1 " ~ op ~ " exp2;");
        if (!ok)
        {
            Unittest.num_failed++;
            throw new TestException(
                this.name,
                Format("Expression '{} {} {}' evaluates to false", exp1, op, exp2),
                this.file,
                line
            );
        }
    }

    /***************************************************************************

        Enable output using tango loggers for the duration of the current
        unittest

    ***************************************************************************/

    deprecated public void output ( )
    {
        Log.root.add(new AppendConsole);
    }

    /***************************************************************************

        Dispose-Destructor

        If the test failed, a message is outputed

    ***************************************************************************/

    protected override void dispose ( )
    {
        if ( this.failed && this.summary )
        {
            Stderr.formatln("Test {} failed", this.name);
        }
    }
}
