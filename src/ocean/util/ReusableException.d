/******************************************************************************

    Reusable exception base class

    Copyright: Copyright (c) 2011 sociomantic labs. All rights reserved

 ******************************************************************************/

module ocean.util.ReusableException;

import ocean.transition;

/*******************************************************************************

    Enhances Exception with additional mutable message buffer that gets reused
    each time new message gets thrown.

    This mutable buffer is only being used if `Exception.msg` is null and calling
    `ReusableException.enforce` will reset it to null. Using `ReusableException`
    as an instance to free form `enforce` function will assign to plain `msg`
    field instead and temporarily shadow mutable one.

*******************************************************************************/

class ReusableException : Exception
{
    import ocean.core.Exception : ReusableExceptionImplementation;

    mixin ReusableExceptionImplementation!();

    /**************************************************************************

        Constructor

    ***************************************************************************/

    this ( ) { super(null); }

    /***************************************************************************

        Throws this instance if ok is false, 0 or null.

        Params:
            ok   = condition to enforce
            msg  = exception message
            file = source code file
            line = source code line

        Throws:
            this instance if ok is false, 0 or null.

    ***************************************************************************/

    deprecated("Use ReusableException.enforce instead")
    public void assertEx ( T ) ( T ok, cstring msg, istring file, long line )
    {
        this.enforce!(T)(ok, msg, file, line);
    }

    /***************************************************************************

        Sets exception information for this instance.

        Params:
            msg  = exception message
            file = source code file
            line = source code line

        Returns:
            this instance

    ***************************************************************************/

    deprecated("Use ReusableException.set instead")
    public typeof (this) opCall ( lazy cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        return this.set(msg, file, line);
    }
}

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.core.Enforce;
}

unittest
{
    // https://github.com/sociomantic/tango/issues/187

    auto ex = new ReusableException;

    try
    {
        enforce(ex, false, "unexpected length for bwa value");
    }
    catch (ReusableException ex)
    {
        ex.set("Failed to parse number", __FILE__, __LINE__);
    }
}
