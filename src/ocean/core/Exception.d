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

version (UnitTest)
{
    import ocean.core.Test;
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

/******************************************************************************

    Common code to implement reusable exception semantics - one that has
    mutable message buffer where message data gets stored to

******************************************************************************/

public template ReusableExceptionImplementation()
{
    import tango.text.convert.Integer;
    static import ocean.core.Array;

    static assert (is(typeof(this) : Exception));

    /**************************************************************************

        Fields used instead of `msg` for mutable messages. `Exception.msg`
        has `istring` type thus can't be overwritten with new data

    ***************************************************************************/

    protected mstring reused_msg;

    /***************************************************************************

        Constructs exception object with mutable buffer pre-allocated to length
        `size` and other fields kept invalid.

        Params:
            size = initial size/length of mutable message buffer

    ***************************************************************************/

    this (size_t size = 128)
    {
        this.reused_msg.length = size;
        super(null);
    }

    /***************************************************************************

        Sets exception information for this instance.

        Params:
            msg  = exception message

        Returns:
            this instance

    ***************************************************************************/

    public typeof (this) set ( cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        ocean.core.Array.copy(this.reused_msg, msg);
        this.msg  = null;
        this.file = file;
        this.line = line;
        return this;
    }

   /***************************************************************************

        Throws this instance if ok is false, 0 or null.

        Params:
            ok   = condition to enforce
            msg  = exception message

        Throws:
            this instance if ok is false, 0 or null.

    ***************************************************************************/

    public void enforce ( T ) ( T ok, lazy cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        if (!ok)
            throw this.set(msg, file, line);
    }

    version (D_Version2)
    {
        /**********************************************************************

            Params:
                sink = delegate that will be called with parts of currently
                    active exception message

        ***********************************************************************/

        mixin(`
        public override void toString(scope void delegate(in char[]) sink) const
        {
            sink(this.msg is null ? this.reused_msg : this.msg);
        }

        alias toString = super.toString;
        `);
    }
    else
    {
        /**********************************************************************

            Returns:
                currently active exception message

        **********************************************************************/

        public override istring toString()
        {
            return this.msg is null ? this.reused_msg : this.msg;
        }
    }

    /**************************************************************************

        Appends new substring to mutable exception message

        Intended to be used in hosts that do dynamic formatting of the
        error message and want to avoid repeating allocation with help
        of ReusableException semantics

        Leaves other fields untouched

        Params:
            msg = string to append to the message

        Returns:
            this instance

    ***************************************************************************/

    public typeof (this) append ( istring msg )
    {
        ocean.core.Array.append(this.reused_msg, msg);
        return this;
    }

    /**************************************************************************

        Appends an integer to mutable exception message

        Does not cause any appenditional allocations

        Params:
            num = number to be formatted
            hex = optional, indicates that value needs to be formatted as hex

        Returns:
            this instance

    **************************************************************************/

    public typeof (this) append ( long num, bool hex = false )
    {
        char[long.max.stringof.length + 1] buff;
        if (hex)
        {
            ocean.core.Array.append(this.reused_msg, "0x");
            ocean.core.Array.append(this.reused_msg, format (buff, num, "X"));
        }
        else
            ocean.core.Array.append(this.reused_msg, format (buff, num));
        return this;
    }
}

///
unittest
{
    auto e = new SomeReusableException(100);

    e.set("message");
    assert (e.toString() == "message");
    auto old_ptr = e.reused_msg.ptr;

    try
    {
        enforce(e, false, "immutable");
        assert (false);
    }
    catch (SomeReusableException) { }
    assert (e.toString() == "immutable");

    try
    {
        e.enforce(false, "longer message");
    }
    catch (SomeReusableException) { }
    assert (e.toString() == "longer message");
    assert (old_ptr is e.reused_msg.ptr);

    try
    {
        e.badName("NAME", 42);
    }
    catch (SomeReusableException) { }
    assert (e.toString() == "Wrong name (NAME) 0x2A 42");
    assert (old_ptr is e.reused_msg.ptr);
}

version (UnitTest)
{
    private class SomeReusableException : Exception
    {
        void badName(istring name, uint id)
        {
            this.set("Wrong name (")
                .append(name)
                .append(") ")
                .append(id, true)
                .append(" ")
                .append(id);
            throw this;
        }

        mixin ReusableExceptionImplementation!();
    }
}


/******************************************************************************

    Common code to implement exception constructor, which takes a message as
    a required parameter, and file and line with default value, and forward
    it to the `super` constructor

******************************************************************************/

public template DefaultExceptionCtor()
{
    public this (istring msg, istring file = __FILE__,
                 typeof(__LINE__) line = __LINE__)
    {
        super (msg, file, line);
    }
}

version (UnitTest)
{
    public class CardBoardException : Exception
    {
        mixin DefaultExceptionCtor;
    }
}

///
unittest
{
    auto e = new CardBoardException("Transmogrification failed");
    try
    {
        throw e;
    }
    catch (CardBoardException e)
    {
        test!("==")(e.msg, "Transmogrification failed");
        test!("==")(e.file, __FILE__);
        test!("==")(e.line, __LINE__ - 9);
    }
}
