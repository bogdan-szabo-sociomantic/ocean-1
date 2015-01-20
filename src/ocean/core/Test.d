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

import ocean.core.Exception;

import tango.text.convert.Format;

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
        test = enforceImpl!(TestException)

    Same arguments as enforceImpl.

******************************************************************************/

public void test ( T ) ( T ok, char[] msg = "",
    char[] file = __FILE__, size_t line = __LINE__ )
{
    if (!msg.length)
    {
        msg = "unit test has failed";
    }
    enforceImpl!(TestException, T)(ok, msg, file, line);
}

/******************************************************************************

    ditto

******************************************************************************/

public void test ( char[] op, T1, T2 ) ( T1 a,
    T2 b, char[] file = __FILE__, size_t line = __LINE__ )
{
    enforceImpl!(op, TestException)(a, b, file, line);
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

    Verifies that given expression throws exception instance of expected type.

    Params:
        expr = expression that is expected to throw during evaluation
        strict = if 'true', accepts only exact exception type, disallowing
            polymorphic conversion
        file = file of origin
        line = line of origin

    Template Params:
        E = exception type to expect, Exception by default
        R = return type of the expression, void by default (deduced)

    Throws:
        `TestException` if nothing has been thrown from `expr`
        Propagates any thrown exception which is not `E`
        In strict mode (default) also propagates any children of E (disables
        polymorphic catching)

******************************************************************************/

public void testThrown ( E : Exception = Exception, R = void ) ( lazy R expr,
    bool strict = true, char[] file = __FILE__, int line = __LINE__ )
{
    bool was_thrown = false;
    try
    {
        expr;
    }
    catch (E e)
    {
        if (strict)
        {
            if (E.classinfo == e.classinfo)
            {
                was_thrown = true;
            }
            else
            {
                throw e;
            }
        }
        else
        {
            was_thrown = true;
        }
    }

    if (!was_thrown)
    {
        throw new TestException(
            "Expected '" ~ E.stringof ~ "' to be thrown, but it wasn't",
            file,
            line
        );
    }
}

unittest
{
    void foo() { throw new Exception(""); }
    testThrown(foo());

    int bar() { throw new Exception(""); return 10; }
    testThrown(bar());

    void test_foo() { throw new TestException("", "", 0); }
    testThrown!(TestException)(test_foo());

    // make sure only exact exception type is caught
    testThrown!(TestException)(
        testThrown!(Exception)(test_foo())
    );

    // .. unless strict matching is disabled
    testThrown!(Exception)(test_foo(), false);
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

        Same as enforceImpl!(TestException) but uses this.name for error message
        formatting.

    ***************************************************************************/

    public void test ( T ) ( T ok, char[] msg = "", char[] file = __FILE__,
        size_t line = __LINE__ )
    {
        // uses `enforceImpl` instead of `test` so that pre-constructed
        // exception instance can be used.
        if (!msg.length)
        {
            msg = "unit test has failed";
        }
        enforceImpl(this, ok, msg, file, line);
    }

    /**************************************************************************

        Same as enforceImpl!(op, TestException) but uses this.name for error message
        formatting.

    ***************************************************************************/

    public void test ( char[] op, T1, T2 ) ( T1 a, T2 b,
        char[] file = __FILE__, size_t line = __LINE__ )
    {
        // uses `enforceImpl` instead of `test` so that pre-constructed
        // exception instance can be used.
        enforceImpl!(op)(this, a, b, file, line);
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
