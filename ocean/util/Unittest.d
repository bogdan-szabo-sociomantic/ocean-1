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

private import ocean.util.log.Trace;

private import Integer = tango.text.convert.Integer;

private import tango.util.log.AppendConsole;

private import tango.util.log.Log;

/*******************************************************************************

    Unittest scope class

    Helper class to enable the possibility to run all unittests, not just
    all till one fails.

    Usage Example
    --------
    import ocean.util.Unittest;

    unittest
    {
        scope t = new Unittest(__FILE__, "ExampleTest");

        t.assertLog( 1 == 2, __LINE__);
        t.assertLog( 1 == 1, "Basic logic failed", __LINE__);

        with (t)
        {
            assertLog( 2 + 2 == 4, "Math failed", __LINE__);
        }
    }

    void main ( )
    {
        Unittest.check();  // Required call
    }
    -------
    This example would output:

    Assert example.d:6 failed
    Assert example.d:12 failed: Math failed
    Test ExampleTest failed
    object.Exception: 1 of 1 Unittests failed!

*******************************************************************************/

scope class Unittest
{
    /***************************************************************************

        Amount of unittests and how many of them failed

    ***************************************************************************/

    static private size_t num_failed, num_all;

    /***************************************************************************

        File and name of the test

    ***************************************************************************/

    char[] test, file;

    /***************************************************************************

        Whether this test failed

    ***************************************************************************/

    bool failed = false;

    /***************************************************************************

        Whether any test failed

        Params:
            throw_ = if true, will throw any exception, else false

        Returns:
            true when no test failed, else false

    ***************************************************************************/

    static bool check ( bool throw_ = true )
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

    ***************************************************************************/

    this ( char[] file, char[] test )
    {
        Unittest.num_all++;

        this.test = test;
        this.file = file;
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

        Dispose-Destructor

        If the test failed, a message is outputed

    ***************************************************************************/

    void dispose ( )
    {
        if ( failed )
        {
            Trace.formatln("Test {} failed", this.test);
        }
    }

    /***************************************************************************

        Assert method that logs any error with the given line

        Params:
            ok   = true: the assert was satisfied, false the assert was unhappy
            line = line at which the assert happened

    ***************************************************************************/

    void assertLog ( lazy bool ok, size_t line )
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

    void assertLog ( lazy bool ok, char[] msg = null, size_t line = 0 )
    {
        void print ( )
        {
            if ( line > 0 )
            {
                Trace.formatln("Assert {}:{} failed{}",
                               this.file, line, msg);
            }
            else
            {
                Trace.formatln("Assert {} failed{}",
                               this.file,  msg);
            }
        }

        try if ( ok == false )
        {
            if ( msg !is null ) msg = ": " ~ msg;

            this.failed = true;

            print();
        }
        catch ( Exception e )
        {
            this.failed = true;

            Trace.formatln("Caught exception while executing assert check: {}:{} {}",
                           e.file, e.line, e.msg);
            print();
        }
    }

    /***************************************************************************

        Enable output using tango loggers for the duration of the current
        unittest

    ***************************************************************************/

    public void output ( )
    {
        Log.root.add(new AppendConsole);
    }
}