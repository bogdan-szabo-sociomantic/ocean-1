/******************************************************************************

    Tokyo Cabinet Exception

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Mar 2013: Initial release

    author:         Hans Bjerkander

 ******************************************************************************/

module ocean.db.tokyocabinet.util.TokyoCabinetException;

/******************************************************************************

    TokyoCabinetException

*******************************************************************************/

class TokyoCabinetException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static void opCall ( Args ... ) ( Args args )
    {
        throw new TokyoCabinetException(args);
    }

    static class Cursor : TokyoCabinetException
    {
        this ( char[] msg ) { super(msg); }
        this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

        static void opCall ( Args ... ) ( Args args )
        {
            throw new Cursor(args);
        }
    }
}
