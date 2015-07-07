/******************************************************************************

    Tokyo Cabinet Exception

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Mar 2013: Initial release

    author:         Hans Bjerkander

 ******************************************************************************/

module ocean.db.tokyocabinet.util.TokyoCabinetException;


import ocean.core.Exception;

/******************************************************************************

    TokyoCabinetException

*******************************************************************************/

class TokyoCabinetException : Exception
{
    mixin DefaultExceptionCtor;

    static class Cursor : TokyoCabinetException
    {
        mixin DefaultExceptionCtor;
    }
}
