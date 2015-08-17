/******************************************************************************

    Compress Exception

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Mar 2013: Initial release

    author:         Hans Bjerkander

 ******************************************************************************/

module ocean.io.compress.CompressException;

import ocean.core.Exception;

/******************************************************************************

    TokyoCabinetException

*******************************************************************************/

class CompressException : Exception
{
    mixin DefaultExceptionCtor!();

    static void opCall ( Args ... ) ( Args args )
    {
        throw new CompressException(args);
    }
}
