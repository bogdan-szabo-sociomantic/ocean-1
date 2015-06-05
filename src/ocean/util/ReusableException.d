/******************************************************************************

    Reusable exception base class

    Copyright: Copyright (c) 2011 sociomantic labs. All rights reserved

 ******************************************************************************/

module ocean.util.ReusableException;

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
    import tango.transition;

    import ocean.core.Array : copy;

    /**************************************************************************

        Fields used instead of `msg` for mutable messages. `Exception.msg`
        has `istring` type thus can't be overwritten with new data

    ***************************************************************************/

    private mstring reused_msg;

    /**************************************************************************

        Constructor

    ***************************************************************************/

    this ( ) { super(null); }

    /***************************************************************************

        Throws this instance if ok is false, 0 or null.

        Params:
            ok   = condition to assert
            msg  = exception message
            file = source code file
            line = source code line

        Throws:
            this instance if ok is false, 0 or null.

    ***************************************************************************/

    public void enforce ( T ) ( T ok, lazy cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        static if (is (T : typeof (null)))
        {
            bool err = ok is null;
        }
        else
        {
            bool err = !ok;
        }

        if (err) throw this.opCall(msg, file, line);
    }

    deprecated("Use ReusableException.enforce instead")
    public void assertEx ( T ) ( T ok, cstring msg, istring file, long line )
    {
        this.enforce!(T)(ok, msg, file, line);
    }

    /***************************************************************************

        Sets exception information for this instance.

        Params:
            ok   = condition to assert
            msg  = exception message
            file = source code file

        Returns:
            this instance

    ***************************************************************************/

    public typeof (this) opCall ( lazy cstring msg, istring file = __FILE__,
        long line = __LINE__ )
    {
        this.reused_msg.copy(msg);
        super.msg  = null;
        super.file = file;
        super.line = line;
        return this;
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
}

version (UnitTest)
{
    import ocean.core.Test;
    import ocean.core.Exception;
}

unittest
{
    auto e = new ReusableException;

    e("message");
    test!("==")(e.toString(), "message");
    auto old_ptr = e.reused_msg.ptr;

    testThrown!(ReusableException)(enforce(e, false, "immutable"));
    test!("==")(e.toString(), "immutable");

    testThrown!(ReusableException)(e.enforce(false, "longer message"));
    test!("==")(e.toString(), "longer message");
    test!("is")(old_ptr, e.reused_msg.ptr);
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
        ex("Failed to parse number", __FILE__, __LINE__);
    }
}
