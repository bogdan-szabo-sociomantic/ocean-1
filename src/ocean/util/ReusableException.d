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
}

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.core.Enforce;
}

unittest
{
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
