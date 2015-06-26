/*******************************************************************************

    Copyright:      Copyright (C) 2014 sociomantic labs. All rights reserved

    Key exception -- thrown when an error event was reported for a selected key.

*******************************************************************************/

module ocean.io.select.selector.EpollException;

/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.sys.ErrnoException;

/******************************************************************************/

class EpollException : ErrnoException
{
    /**************************************************************************

        Queries and resets errno and sets the exception parameters.

        Params:
            msg  = message
            file = source code file name
            line = source code line

        Returns:
            this instance

     **************************************************************************/

    deprecated("Use ocean.sys.ErrnoException.enforce instead")
    public typeof (this) opCall ( char[] msg, char[] file = __FILE__,
        int line = __LINE__ )
    {
        this.useGlobalErrno("<unknown>", file, line)
            .append(" (").append(msg).append(")");
        return this;
    }

    /**************************************************************************

        Sets the exception parameters.

        Params:
            errnum = error number
            msg    = message
            file   = source code file name
            line   = source code line

        Returns:
            this instance

     **************************************************************************/

    deprecated("Use ocean.sys.ErrnoException.enforce instead")
    public typeof (this) opCall  ( int errnum, char[] msg,
        char[] file = __FILE__, int line = __LINE__ )
    {
        this.set(errnum, "", file, line).append(" (").append(msg).append(")");
        return this;
    }

    /**************************************************************************

        Provided instead of old ErrnoIOException.assertEx to minimize breakage
        with new base class.

        Params:
            ok    = success condition
            msg   = message

        Throws:
            this if !ok

    ***************************************************************************/

    deprecated ("use ocean.sys.ErrnoException.enforce instead")
    void assertEx ( bool ok, cstring msg, istring file = __FILE__,
        int line = __LINE__ )
    {
        this.enforce(ok, "<unknown name>", msg, file, line);
    }
}
