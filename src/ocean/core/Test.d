/******************************************************************************

  Defines base exception class thrown by test checks and set of helper
  functions to define actual test cases. These helpers are supposed to be
  used in unittest blocks instead of asserts.

  Copyright:      Copyright (c) 2014 sociomantic labs.

*******************************************************************************/

module ocean.core.Test;

/*******************************************************************************

  Imports

********************************************************************************/

private import ocean.core.Exception;

private import tango.text.convert.Format;

/******************************************************************************

    Exception class to be thrown from unot tests blocks.
  
*******************************************************************************/

class TestException : Exception
{
    /***************************************************************************

      wraps parent constructor

     ***************************************************************************/

    public this ( char[] msg, char[] file = __FILE__, size_t line = __LINE__ )
    {
        super( msg, file, line );
    }
}

/******************************************************************************

    Effectively partial specialization alias:
        test = enforce!(TestException)

    Same arguments as enforce.

******************************************************************************/

public void test ( T ) ( T ok, char[] msg = "",
    char[] file = __FILE__, size_t line = __LINE__ )
{
    if (!msg.length)
    {
        msg = "unit test has failed";
    }
    enforce!(TestException)(ok, msg, file, line);
}

/******************************************************************************

    ditto

******************************************************************************/

public void test ( char[] op, T1, T2 ) ( T1 a,
    T2 b, char[] file = __FILE__, size_t line = __LINE__ )
{
    enforce!(op, TestException)(a, b, file, line);
}

unittest
{
    try
    {
        test(false);
        assert(false);
    }
    catch (TestException e)
    {
        assert(e.msg == "unit test has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        test!("==")(2, 3);
        assert(false);
    }
    catch (TestException e)
    {
        assert(e.msg == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }
}

/******************************************************************************

    Utility class useful in scenarios where actual testing code is reused in
    different contexts and file+line information is not enough to uniquely
    identify failed case.

    NamedTest is also exception class on its own - when test condition fails
    it throws itself.

******************************************************************************/

class NamedTest : TestException
{
    /***************************************************************************

      Field to store test name this check belongs to. Useful
      when you have a common verification code reused by different test cases
      and file+line is not enough for identification.

     ***************************************************************************/

    private char[] name;

    /**************************************************************************
    
        Constructor

    ***************************************************************************/

    this(char[] name)
    {
        super(null);
        this.name = name;
    }

    /***************************************************************************

      toString that also uses this.name if present

     ***************************************************************************/

    public override char[] toString()
    {
        if (this.name.length)
        {
            return Format("[{}] {}", this.name, this.msg);
        }
        else
        {
            return Format("{}", this.msg);
        }
    }

    /**************************************************************************

        Same as enforce!(TestException) but uses this.name for error message
        formatting. 

    ***************************************************************************/

    public void test ( T ) ( T ok, char[] msg = "", char[] file = __FILE__,
        size_t line = __LINE__ )
    {
        // uses `enforce` instead of `test` so that pre-constructed
        // exception instance can be used.
        if (!msg.length)
        {
            msg = "unit test has failed";
        }
        enforce(this, ok, msg, file, line);
    }

    /**************************************************************************

        Same as enforce!(op, TestException) but uses this.name for error message
        formatting. 

    ***************************************************************************/

    public void test ( char[] op, T1, T2 ) ( T1 a, T2 b,
        char[] file = __FILE__, size_t line = __LINE__ )
    {
        // uses `enforce` instead of `test` so that pre-constructed
        // exception instance can be used.
        enforce!(op)(this, a, b, file, line);
    }
}

unittest
{
    auto t = new NamedTest("name");

    t.test(true);

    try
    {
        t.test(false);
        assert(false);
    }
    catch (TestException e)
    {
        assert(e.toString() == "[name] unit test has failed");
    }

    try
    {
        t.test!(">")(2, 3);
        assert(false);
    }
    catch (TestException e)
    {
        assert(e.toString() == "[name] expression '2 > 3' evaluates to false");
    }
}
