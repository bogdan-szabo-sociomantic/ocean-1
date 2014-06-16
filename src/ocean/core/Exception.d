/******************************************************************************

    Ocean Exceptions

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt & Thomas Nicolai


*******************************************************************************/

module ocean.core.Exception;


/******************************************************************************

    opCall template for Exception classes

*******************************************************************************/

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
