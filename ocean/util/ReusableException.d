/******************************************************************************

    Reusable exception base class

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    authors:        David Eckardt

 ******************************************************************************/

module ocean.util.ReusableException;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.core.Array: copy;

/******************************************************************************/

class ReusableException : Exception
{
    /**************************************************************************

        Constructor

     **************************************************************************/

    this ( ) {super("");}

    /**************************************************************************

        Throws this instance if ok is false, 0 or null.

        Params:
            ok   = condition to assert
            msg  = exception message
            file = source code file
            line = source code line

        Throws:
            this instance if ok is false, 0 or null.

     **************************************************************************/

    void assertEx ( T ) ( T ok, char[] msg, char[] file, long line )
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

    /**************************************************************************

        Sets exception information for this instance.

        Params:
            ok   = condition to assert
            msg  = exception message
            file = source code file

        Returns:
            this instance

     **************************************************************************/

    typeof (this) opCall ( char[] msg, char[] file, long line )
    {
        super.msg.copy(msg);
        super.file.copy(file);
        super.line = line;
        return this;
    }
}