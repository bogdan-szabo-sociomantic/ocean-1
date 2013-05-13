/******************************************************************************

    Tokyo Cabinet B+ Tree Database Cursor

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Mar 2010: Initial release

    author:         David Eckardt

    Description:

        The TokyoCabinetCursor class encapsulates TCBDB and provides a cursor
        object for a B+ Tree database.
        To create a cursor, call TokyoCabinetB.getCursor().
        TokyoCabinetCursor class instances are created from TokyoCabinetB class
        instances and returned from TokyoCabinetB class methods.

 ******************************************************************************/

module ocean.db.tokyocabinet.util.TokyoCabinetCursor;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.core.Exception: assertEx;

private import ocean.db.tokyocabinet.c.util.tcxstr:  TCXSTR;
private import ocean.db.tokyocabinet.c.bdb.tcbdbcur: BDBCUR,
                                                     tcbdbcurnew,   tcbdbcurdel,
                                                     tcbdbcurfirst, tcbdbcurlast,
                                                     tcbdbcurjump,  tcbdbcurjumpback,
                                                     tcbdbcurprev,  tcbdbcurnext,
                                                     tcbdbcurout,   tcbdbcurrec,
                                                     tcbdbcurkey3;

private import ocean.db.tokyocabinet.c.tcbdb:        TCBDB;

private import ocean.db.tokyocabinet.util.TokyoCabinetException;
private import ocean.db.tokyocabinet.util.TokyoCabinetExtString;

debug private import tango.util.log.Trace;

/******************************************************************************

    TokyoCabinetCursor class

 ******************************************************************************/


class TokyoCabinetCursor
{
    /**************************************************************************

        This alias for chainable methods

    ***************************************************************************/

    private alias typeof (this) This;

    /**************************************************************************

        Tokyo Cabinet B+ tree database cursor object

    ***************************************************************************/

    private BDBCUR* cursor;

    /**************************************************************************

        Extensible string instances for key and value, used in get()

    ***************************************************************************/

    private TokyoCabinetExtString xkey, xval;

    /**************************************************************************

        Constructor

        Creates a Cursor instance from a TCBDB (database) object

    ***************************************************************************/

    this ( TCBDB* db )
    {
        this.cursor = tcbdbcurnew(db);

        this();
    }

    /**************************************************************************

        Constructor

        Creates a Cursor instance for a BDBCUR (cursor) object

    ***************************************************************************/

    this ( BDBCUR* cursor )
    {
        this.cursor = cursor;

        this();
    }

    /**************************************************************************

        Constructor

        Must be invoked by any public constructor

    ***************************************************************************/

    private this ( )
    {
        this.xkey = new TokyoCabinetExtString;
        this.xval = new TokyoCabinetExtString;
    }

    /**************************************************************************

        Moves the cursor to the first record

        Returns:
            this instance

    ***************************************************************************/

    public This selectStart ( )
    {
        return this.cursorAssert!(tcbdbcurfirst, "selectStart")();
    }

    /**************************************************************************

        Moves the cursor to the last record

        Returns:
            this instance

    ***************************************************************************/

    public This selectEnd ( )
    {
        return this.cursorAssert!(tcbdbcurlast, "selectEnd");
    }

    /**************************************************************************

        Moves the cursor to the first record which matches key

        Params:
            key = record key

        Returns:
            this instance

    ***************************************************************************/

    public This select ( char[] key )
    {
        return this.cursorAssert!(tcbdbcurjump, "select")(key.ptr, key.length);
    }

    public alias select opAssign;

    /**************************************************************************

        Moves the cursor to the last record which matches key

        Params:
            key = record key

        Returns:
            this instance

    ***************************************************************************/

    public This selectLast ( char[] key )
    {
        return this.cursorAssert!(tcbdbcurjumpback, "selectLast")(key.ptr, key.length);
    }

    /**************************************************************************

        Moves the cursor to the previous record

        Returns:
            this instance

    ***************************************************************************/

    public This prev ( )
    {
        return this.cursorAssert!(tcbdbcurprev, "prev")();
    }

    public alias prev opPostDec;

    /**************************************************************************

        Moves the cursor to the next record

        Returns:
            this instance

    ***************************************************************************/

    public This next ( )
    {
        return this.cursorAssert!(tcbdbcurnext, "next")();
    }

    public alias next opPostInc;

    /**************************************************************************

        Removes the record at current cursor position

        Returns:
            this instance

    ***************************************************************************/

    public This remove ( )
    {
        return this.cursorAssert!(tcbdbcurout, "remove")();
    }

    /**************************************************************************

        Retrieves the record at current cursor position

        Params:
            key = record key output
            val = record value output

        Returns:
            this instance

     ***************************************************************************/

    public This get ( ref char[] key, ref char[] val )
    {
        scope (success)
        {
            key = this.xkey.toString();
            val = this.xval.toString();
        }

        return this.cursorAssert!(tcbdbcurrec, "get")(this.xkey.getNative(), this.xval.getNative());
    }

    /**************************************************************************

        Retrieves the key at current cursor position

        Params:
            key = record key output
            val = record value output

        Returns:
            this instance

    ***************************************************************************/

    public This get ( ref char[] key )
    {
        key.length = 0;

        int len;

        char* key_ = cast (char*) tcbdbcurkey3(this.cursor, &len);

        assertEx!(TokyoCabinetException.Cursor)(!!key_, This.stringof ~ ".get: key not found");

        key = key_[0 .. len];

        return this;
    }

    /**************************************************************************

        Invokes func and asserts that func returns true. func must be of type
            ---
                bool ( BDBCUR* cursor, Args args )
            ---
            Params:
                cursor = BDBCUR object
                args   = additional arguments (Args may be 'void' if no
                         argument)

            Returns:
                true on success or false otherwise

        . fname is the function name for assertion message composition.

        Params:
            args = additional func arguments

        Returns:
            this instance

        Throws:
            TokyoCabinetException.Cursor if func returned false

    ***************************************************************************/

    private This cursorAssert ( alias func, char[] fname, Args ... ) ( Args args )
    {
        bool ok = func(this.cursor, args);

        assertEx!(TokyoCabinetException.Cursor)(ok, This.stringof ~ '.' ~ fname ~ ": key not found");

        return this;
    }

    /**************************************************************************

        Descructor

    ***************************************************************************/

    private ~this ( )
    {
        tcbdbcurdel(this.cursor);

        delete this.xkey;
        delete this.xval;
    }
}
