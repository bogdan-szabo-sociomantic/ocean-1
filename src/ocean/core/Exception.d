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
