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

import tango.text.convert.Format;
import tango.transition;

public import tango.core.Enforce : enforce, enforceImpl;

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
                  ( lazy Throwable e, lazy istring msg, istring file = __FILE__,
                    size_t line = __LINE__ )
{
    throw new E(msg, file, line, e);
}

unittest
{
    auto next_e = new Exception("1");

    try
    {
        throwChained!(Exception)(next_e, "2");
        assert (false);
    }
    catch (Exception e)
    {
        assert (e.next is next_e);
        assert (e.msg == "2");
        assert (e.next.msg == "1");
    }
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

    private Throwable root;


    /**************************************************************************

        Allows the user to iterate over the exception chain

    ***************************************************************************/

    public int opApply (int delegate (ref Throwable) dg)
    {
        int result;

        for (auto e = root; e !is null; e = e.next)
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

unittest
{
    auto e1 = new Exception("1");
    auto e2 = new Exception("2", __FILE__, __LINE__, e1);

    size_t counter;
    foreach (e; ExceptionChain(e2))
        ++counter;
    assert (counter == 2);
}
