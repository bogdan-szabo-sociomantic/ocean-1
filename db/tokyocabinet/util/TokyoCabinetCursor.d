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

private import ocean.db.tokyocabinet.c.tcutil: TCXSTR;

private import ocean.db.tokyocabinet.c.tcbdb:   BDBCUR,        TCBDB,
                                                tcbdbcurnew,   tcbdbcurdel,
                                                tcbdbcurfirst, tcbdbcurlast,
                                                tcbdbcurjump,  tcbdbcurjumpback,
                                                tcbdbcurprev,  tcbdbcurnext,
                                                tcbdbcurout,   tcbdbcurrec;

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
    
        Constructor
        
        Creates a Cursor instance from a TCBDB (database) object
        
    ***************************************************************************/
    
    this ( TCBDB* db )
    {
        this.cursor = tcbdbcurnew(db);
    }
    
    /**************************************************************************
    
        Constructor
        
        Creates a Cursor instance for a BDBCUR (cursor) object
        
    ***************************************************************************/
    
    this ( BDBCUR* cursor )
    {
        this.cursor = cursor;
    }
    
    
    /**************************************************************************
    
        Moves the cursor to the first record
        
        Returns:
            this instance
        
    ***************************************************************************/
    
    public This selectStart ( )
    {
        return this.cursorAssert!(tcbdbcurfirst, "moveToStart")();
    }
    
    /**************************************************************************
    
        Moves the cursor to the last record
        
        Returns:
            this instance
        
    ***************************************************************************/
    
    public This selectEnd ( )
    {
        return this.cursorAssert!(tcbdbcurlast, "moveToEnd");
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
        return this.cursorAssert!(tcbdbcurjump, "moveTo")(key.ptr, key.length);
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
        return this.cursorAssert!(tcbdbcurjumpback, "moveToLast")(key.ptr, key.length);
    }
    
    /**************************************************************************
    
        Moves the cursor to the previous record
        
        Returns:
            this instance
        
    ***************************************************************************/
    
    public This prev ( )
    {
        return this.cursorAssert!(tcbdbcurprev, "moveToPrev")();
    }
    
    public alias prev opPostDec;
    
    /**************************************************************************
    
        Moves the cursor to the next record
        
        Returns:
            this instance
        
    ***************************************************************************/
    
    public This next ( )
    {
        return this.cursorAssert!(tcbdbcurnext, "moveToNext")();
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
    
    public This get ( out char[] key, out char[] val )
    {
        TCXSTR key_, val_;
        
        scope (success)
        {
            key = key_.ptr[0 .. key_.size];
            val = val_.ptr[0 .. val_.size];
        }
        
        return this.cursorAssert!(tcbdbcurrec, ".get")(&key_, &val_);
    }
    
    /**************************************************************************
    
        Invokes func and asserts that func returns true. func must be of
        type
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
        
    ***************************************************************************/
    
    private This cursorAssert ( alias func, char[] fname, Args ... ) ( Args args )
    {
        bool ok = func(this.cursor, args);
        
        assert (ok, This.stringof ~ '.' ~ fname ~ ": key not found");
        
        return this;
    }
    
    /**************************************************************************
    
        Descructor
        
    ***************************************************************************/
    
    private ~this ( )
    {
        tcbdbcurdel(this.cursor);
    }
} // Cursor class
