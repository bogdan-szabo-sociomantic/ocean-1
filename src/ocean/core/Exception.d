/******************************************************************************

    Ocean Exceptions

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt & Thomas Nicolai


*******************************************************************************/

module ocean.core.Exception;

/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.text.convert.Format;

/******************************************************************************

    Enforces that given expression evaluates to boolean `true` after
    implicit conversion.

    Template Params:
        E = exception type to create and throw
        T = type of expression to test

    Params:
        ok = result of expression
        msg = optional custom message for exception
        file = file of origin
        line = line of origin

    Throws:
        E if expression evaluates to false

******************************************************************************/

public void enforce ( E : Exception = Exception, T ) ( T ok, lazy char[] msg = "",
    char[] file = __FILE__, size_t line = __LINE__ )
{
    // duplicate msg/file/line mention to both conform Exception cnstructor
    // signature and fit our reusable exceptions.

    E exception = null;

    if (!ok)
    {
        static if (is(typeof(new E((char[]).init, file, line))))
        {
            exception = new E(null, file, line);
        }
        else static if (is(typeof(new E(file, line))))
        {
            exception = new E(file, line);
        }
        else static if (is(typeof(new E((char[]).init))))
        {
            exception = new E(null);
        }
        else static if (is(typeof(new E())))
        {
            exception = new E();
        }
        else
        {
            static assert (false, "Unsupported constructor signature");
        }
    }

    enforce!(E, T)(exception, ok, msg, file, line);
}

unittest
{
    // uses 'assert' to avoid dependency on itself

    enforce(true);

    try
    {
        enforce(false);
        assert(false);
    }
    catch (Exception e)
    {
        assert(e.msg == "enforcement has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce(3 > 4, "custom message");
        assert(false);
    }
    catch (Exception e)
    {
        assert(e.msg == "custom message");
        assert(e.line == __LINE__ - 6);
    }
}

/******************************************************************************

    Enforces that given expression evaluates to boolean `true` after
    implicit conversion.

    NB! When present 'msg' is used instead of existing 'e.msg'

    In D2 we will be able to call this via UFCS:
        exception.enforce(1 == 1);

    Template Params:
        E = exception type to create and throw
        T = type of expression to test

    Params:
        e = exception instance to throw in case of an error
        ok = result of expression
        msg = optional custom message for exception
        file = file of origin
        line = line of origin

    Throws:
        e if expression evaluates to false

******************************************************************************/

public void enforce ( E : Exception, T ) ( E e, T ok, lazy char[] msg = "",
    char[] file = __FILE__, size_t line = __LINE__ )
{
    if (!ok)
    {
        if (msg.length)
        {
            e.msg = msg;
        }
        else
        {
            if (!e.msg.length)
            {
                e.msg = "enforcement has failed";
            }
        }

        e.file = file;
        e.line = line;

        throw e;
    }
}

unittest
{
    class MyException : Exception
    {
        this ( char[] msg, char[] file = __FILE__, size_t line = __LINE__ )
        {
            super ( msg, file, line );
        }
    }

    auto reusable = new MyException(null);

    enforce(reusable, true);

    try
    {
        enforce(reusable, false);
        assert(false);
    }
    catch (MyException e)
    {
        assert(e.msg == "enforcement has failed");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce(reusable, false, "custom message");
        assert(false);
    }
    catch (MyException e)
    {
        assert(e.msg == "custom message");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce(reusable, false);
        assert(false);
    }
    catch (MyException e)
    {
        // preserved from previous enforcement
        assert(e.msg == "custom message");
        assert(e.line == __LINE__ - 7);
    }

    // Check that enforce won't try to modify the exception reference
    static assert(is(typeof(enforce(new Exception("test"), true))));
}

/******************************************************************************

    enforcement that builds error message string automatically based on value
    of operands and supplied "comparison" operation.
    
    'op' can be any binary operation.

    Template Params:
        op = binary operator string
        E = exception type to create and throw
        T1 = type of left operand
        T2 = type of right operand

    Params:
        a = left operand
        b = right operand
        file = file of origin
        line = line of origin

    Throws:
        E if expression evaluates to false

******************************************************************************/

public void enforce ( char[] op, E : Exception = Exception, T1, T2 ) ( T1 a,
    T2 b, char[] file = __FILE__, size_t line = __LINE__ )
{
    static if (is(typeof(new E((char[]).init, file, line))))
    {
        auto exception = new E(null, file, line);
    }
    else static if (is(typeof(new E(file, line))))
    {
        auto exception = new E(file, line);
    }
    else static if (is(typeof(new E((char[]).init))))
    {
        auto exception = new E(null);
    }
    else static if (is(typeof(new E())))
    {
        auto exception = new E();
    }
    else
    {
        static assert (false, "Unsupported constructor signature");
    }

    enforce!(op, E, T1, T2)(exception, a, b, file, line);
}

unittest
{
    class MyException : Exception
    {
        this ( char[] msg, char[] file = __FILE__, size_t line = __LINE__ )
        {
            super ( msg, file, line );
        }
    }

    auto reusable = new MyException(null);

    enforce!("==")(reusable, 2, 2);

    try
    {
        enforce!("==")(reusable, 2, 3);
        assert(false);
    }
    catch (MyException e)
    {
        assert(e.msg == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce!("is")(reusable, cast(void*)43, cast(void*)42);
        assert(false);
    }
    catch (MyException e)
    {
        assert(e.msg == "expression '2b is 2a' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }
}

/******************************************************************************

    ditto

    Template Params:
        op = binary operator string
        E = exception type to create and throw
        T1 = type of left operand
        T2 = type of right operand

    Params:
        e = exception instance to throw in case of an error
        a = left operand
        b = right operand
        msg = optional custom message for exception
        file = file of origin
        line = line of origin

    Throws:
        e if expression evaluates to false

******************************************************************************/

public void enforce ( char[] op, E : Exception, T1, T2 ) ( E e, T1 a,
    T2 b, char[] file = __FILE__, size_t line = __LINE__ )
{
    mixin("auto ok = a " ~ op ~ " b;");

    if (!ok)
    {
        e.msg = Format("expression '{} {} {}' evaluates to false", a, op, b);
        e.file = file;
        e.line = line;
        throw e;
    }
}

unittest
{
    // uses 'assert' to avoid dependency on itself

    enforce!("==")(2, 2);

    try
    {
        enforce!("==")(2, 3);
        assert(false);
    }
    catch (Exception e)
    {
        assert(e.msg == "expression '2 == 3' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }

    try
    {
        enforce!(">")(3, 4);
        assert(false);
    }
    catch (Exception e)
    {
        assert(e.msg == "expression '3 > 4' evaluates to false");
        assert(e.line == __LINE__ - 6);
    }

    // Check that enforce won't try to modify the exception reference
    static assert(is(typeof(enforce!("==")(new Exception("test"), 2, 3))));
}

/******************************************************************************

    opCall template for Exception classes

*******************************************************************************/

deprecated
template ExceptionOpCalls  ( E : Exception )
{
    void opCall ( Args ... ) ( Args args )
    {
        throw new E(args);
    }
}

/******************************************************************************

    Throws an existing Exception if ok is false, 0 or null.

    Params:
        ok = condition which is challenged for being true or not 0/null
        e  = Exception instance to throw or expression returning that instance.

    Throws:
        e if ok is
            - false or
            - equal to 0 or
            - a null object, reference or pointer.

 ******************************************************************************/

deprecated
void assertEx ( E : Exception = Exception, T ) ( T ok, lazy E e )
{
    if (!ok) throw e;
}

/******************************************************************************

    Throws a new Exception if ok is false, 0 or null.

    Params:
        ok = condition which is challenged for being true or not 0/null

    Throws:
        new E if ok is
            - false or
            - equal to 0 or
            - a null object, reference or pointer.

 ******************************************************************************/

deprecated
void assertEx ( E : Exception = Exception, T ) ( T ok )
{
    if (!ok) throw new E;
}


/******************************************************************************

    Throws exception E if ok is false or equal to 0 or a null object, reference
    or pointer.

    Params:
        ok   = condition which must be true else an exception E is thrown
        msg  = message to pass to exception constructor
        args = additional exception arguments, depending on the particular
               exception

*******************************************************************************/

deprecated
void assertEx ( E : Exception = Exception, T, Args ... ) ( T ok, lazy char[] msg, Args args )
{
    if (!ok) throw new E(msg, args);
}


/******************************************************************************

    Throws a new exception E chained together with an existing exception.

    Template params:
        E = type of exception to throw

    Params:
        e = existing exception to chain with new exception
        msg  = message to pass to exception constructor
        file = file from which this exception was thrown
        line = line from which this exception was thrown

*******************************************************************************/

void throwChained ( E : Exception = Exception )
                  ( lazy Exception e, lazy char[] msg, char[] file = __FILE__,
                    size_t line = __LINE__ )
{
    throw new E(msg, file, line, e);
}


/******************************************************************************

    Creates an iteratable data structure over a chained sequence of
    exceptions.

*******************************************************************************/

struct ExceptionChain
{
    /**************************************************************************

        Exception that forms the root of the exception chain.  This can
        be passed in like a constructor argument:

            foreach (e; ExceptionChain(myException))
            {
                ...
            }

    ***************************************************************************/

    private Exception root;


    /**************************************************************************

        Allows the user to iterate over the exception chain

    ***************************************************************************/

    public int opApply (int delegate (ref Exception) dg)
    {
        int result;

        for (Exception e = root; e !is null; e = e.next)
        {
            result = dg(e);

            if (result)
            {
                break;
            }
        }

        return result;
    }
}
