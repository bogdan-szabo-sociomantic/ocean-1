/******************************************************************************

    Tokyo Cabinet Database base class

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    license:        BSD style: $(LICENSE)

    version:        Mar 2010: Initial release

    author:         Thomas Nicolai, Lars Kirchhoff, David Eckardt

 ******************************************************************************/

module 			ocean.db.tokyocabinet.model.ITokyoCabinet;

/******************************************************************************

    Imports

 ******************************************************************************/

private	        import  ocean.db.tokyocabinet.c.tcutil: TCERRCODE;
private		    import	ocean.text.util.StringC;
private 		import  tango.stdc.stdlib: free;

debug private 		import  tango.util.log.Trace;

/******************************************************************************

    ITokyoCabinet abstract class

    Template parameters:

        TCDB        = Tokyo Cabinet reference type:
                            - TCHDB for TokyoCabinetH
                            - TDBDB for TokyoCabinetB

        tcdbforeach = Tokyo Cabinet 'foreach' function name:
                            - tchdbforeach for TokyoCabinetH
                            - tcbdbforeach for TokyoCabinetB


 ******************************************************************************/

abstract class ITokyoCabinet ( TCDB, alias tcdbforeach )
{
    /******************************************************************************

        TokyoCabinetIterator alias definition for opApply

     *****************************************************************************/

    public alias TokyoCabinetIterator!(TCDB, tcdbforeach) TcIterator;

    /******************************************************************************

        Tokyo Cabinet database object

     *****************************************************************************/

    protected TCDB* db;

    /**************************************************************************

        Tokyo Cabinet put function definition

        The following Tokyo Cabinet functions comply to TchPutFunc:

        ---

            tchdbput()
            tchdbputkeep()
            tchdbputcat()
            tchdbputasync()

        ---

     **************************************************************************/

    extern (C) private alias bool function ( TCDB* hdb, void* key, int ksiz,
                                                        void* val, int vsiz ) TcPutFunc;


    /**************************************************************************

        "foreach" iterator over key/value pairs of records in database. The
        "key" and "val" parameters of the delegate correspond to the iteration
        variables.

     ***************************************************************************/

    public int opApply ( TcIterator.KeyValIterDg delg )
    {
        int result;

        this.tokyoAssertStrict(TcIterator.tcdbopapply(this.db, delg, result), "key/value iteration");

        return result;
    }


    /**************************************************************************

        "foreach" iterator over keys of records in database. The "key"
        parameter of the delegate corresponds to the iteration variable.

     ***************************************************************************/

    public int opApply ( TcIterator.KeyIterDg delg )
    {
        int result;

        this.tokyoAssertStrict(TcIterator.tcdbopapply(this.db, delg, result), "key iteration");

        return result;
    }


    /**************************************************************************

        Invokes put_func to put key/value into the database.

        The following Tokyo Cabinet functions comply to TcPutFunc:

            tchdbput
            tchdbputkeep
            tchdbputcat
            tchdbputasync

            tcbdbput
            tcbdbputcat
            tcbdbputdup
            tcbdbputdupback
            tcbdbputkeep

        Params:
            key             = key of item to put
            value           = item value
            put_func        = Tokyo Cabinet put function
            description     = description string for error messages
            ignore_errcodes = do not throw an exception on these error codes

    ***************************************************************************/

    protected void tcPut ( char[] key, char[] value, TcPutFunc put_func,
                           char[] description, TCERRCODE[] ignore_errcodes = [] )
    in
    {
        assert (key,   "Error on " ~ description ~ ": null key");
        assert (value, "Error on " ~ description ~ ": null value");
    }
    body
    {
//        TODO: this causes a lot of memory allocation!!! TO BE FIXED!!!!
//        this.tokyoAssert(put_func(this.db, key.ptr, key.length, value.ptr, value.length),
//                         ignore_errcodes, "Error on " ~ description);
        this.tokyoAssertStrict(put_func(this.db, key.ptr, key.length, value.ptr, value.length),
              ignore_errcodes);
    }
	/**************************************************************************

	    If p is null, retrieves the current Tokyo Cabinet error code and
	    throws an exception (even if the error code equals TCESUCCESS).

	    Params:
	        p       = not null assertion pointer
	        context = error context description string for message

	***************************************************************************/

	protected void tokyoAssert ( void* p, char[] context = "Error" )
	{
	    this.tokyoAssertStrict(!!p, context);
	}



	/**************************************************************************

	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from TCESUCCESS.

	    Params:
	        ok      = assert condition
	        context = error context description string for message

	***************************************************************************/

	protected void tokyoAssert ( bool ok, char[] context = "Error" )
	{
	    this.tokyoAssert(ok, [], context);
	}



	/**************************************************************************

	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception (even if the error code equals TCESUCCESS).

	    Params:
	        ok      = assert condition
	        context = error context description string for message

	***************************************************************************/

	protected void tokyoAssertStrict ( bool ok, char[] context = "Error" )
	{
	    this.tokyoAssertStrict(ok, [], context);
	}



	/**************************************************************************

	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from TCESUCCESS and
	    all error codes in ignore_codes.

	    Params:
	        ok           = assert condition
	        ignore_codes = do not throw an exception on these codes
	        context      = error context description string for message

	***************************************************************************/

	protected void tokyoAssert ( bool ok, TCERRCODE[] ignore_codes, char[] context = "Error" )
	{
	    this.tokyoAssertStrict(ok, ignore_codes ~ TCERRCODE.TCESUCCESS, context);
	}



	/**************************************************************************

	    Retrieves the current Tokyo Cabinet error message string.

	    Returns:
	        current Tokyo Cabinet error message string

	***************************************************************************/

	abstract protected char[] getTokyoErrMsg ( );



	/**************************************************************************

	    Retrieves the Tokyo Cabinet error message string for errcode.

	    Params:
	        errcode = Tokyo Cabinet error code

	    Returns:
	        Tokyo Cabinet error message string for errcode

	***************************************************************************/

	abstract protected char[] getTokyoErrMsg ( TCERRCODE errcode );



	/**************************************************************************

	    If ok == false, retrieves the current Tokyo Cabinet error code and
	    throws an exception if the error code is different from  all error codes
	    in ignore_codes (even if it equals TCESUCCESS).

	    Params:
	        ok           = assert condition
	        ignore_codes = do not throw an exception on these codes
	        context      = error context description string for message

	***************************************************************************/

	abstract protected void tokyoAssertStrict ( bool ok, TCERRCODE[] ignore_codes, char[] context = "Error" );
}

/******************************************************************************

    TokyoCabinetIterator structure

    TokyoCabinetIterator holds the static tcdbopapply() method which provides a
    means for 'foreach' iteration over the Tokyo Cabinet database. The iteration
    variables are key and value, both of type char[].

    Essentially, TokyoCabinetIterator invokes tcdbforeach(), adapting the D
    'foreach' delegate to the callback function reference of tcdbforeach().

    The provided functionality should be reentrant/thread-safe.

    Usage example:

    ---
        // TODO
    ---

    Template parameters:

        TCDB        = Tokyo Cabinet reference type:
                            - TCHDB for TokyoCabinetH
                            - TDBDB for TokyoCabinetB
                            - TDBDM for TokyoCabinetM

        tcdbforeach = Tokyo Cabinet 'foreach' function name:
                            - tchdbforeach for TokyoCabinetH
                            - tcbdbforeach for TokyoCabinetB
                            - tcbdmforeach for TokyoCabinetM

    @see reference

    http://torum.net/2009/10/iterating-tokyo-cabinet-in-parallel/
    http://torum.net/2009/05/tokyo-cabinet-protected-database-iteration/


******************************************************************************/

struct TokyoCabinetIterator ( TCDB, alias tcdbforeach )
{
    /**************************************************************************

        D 'foreach' key/value and key-only delegate definition

     **************************************************************************/

    public alias int delegate ( ref char[] key, ref char[] val ) KeyValIterDg;
    public alias int delegate ( ref char[] key                 ) KeyIterDg;

    /**************************************************************************

        Definitions of argument structures passed to tcdbforeach() callback

     **************************************************************************/

    struct KeyValIterArgs
    {
        KeyValIterDg dg;
        int result;
        Exception exception;
    }

    struct KeyIterArgs
    {
        KeyIterDg dg;
        int result;
        Exception exception;
    }

    static if (is (typeof (tcdbforeach) R == return) )                          // tcdbopapply() clones the
    {                                                                           // return type of tcdbforeach()
        /**********************************************************************

            Invokes tchdbforeach() with the provided D 'foreach' delegate.

            Params:
                db:     TokyoCabinet database reference
                dg:     D 'foreach' opApply() delegate
                result: return value of dg output

            Returns:
                true on success or false on error. Halting iteration because
                dg returned a value different from 0 is considered success.

         **********************************************************************/

        public static R tcdbopapply ( TCDB* db, KeyValIterDg dg, out int result )
        {
            KeyValIterArgs args = KeyValIterArgs(dg);

            scope (exit) result = args.result;

            return handleExceptions(args, tcdbforeach(db, &tciter_callback_keyval, &args));
        }

        /**********************************************************************

            Invokes tchdbforeach() with the provided D 'foreach' delegate.

            Params:
                db:     TokyoCabinet database reference
                dg:     D 'foreach' opApply() delegate
                result: return value of dg output

            Returns:
                true on success or false on error. Halting iteration because
                dg returned a value different from 0 is considered success.

         **********************************************************************/

        public static R tcdbopapply ( TCDB* db, KeyIterDg dg, out int result )
        {
            KeyIterArgs args = KeyIterArgs(dg);

            scope (exit) result = args.result;

            return handleExceptions(args, tcdbforeach(db, &tciter_callback_key, &args));
        }

        /**********************************************************************

            Safely catches and handles any exceptions which the are thrown
            inside the iteration delegate.

            Exceptions within the iteration delegate are caught by the tokyo
            cabinet callback functions (see tciter_callback_keyval and
            tciter_callback_key, below). As exceptions cannot safely be thrown
            at that point, while inside tokyo cabinet, any exceptions are stored
            in the args structure, and are rethrown at this point, outside of
            the C code.

            Template params:
                A = type of args struct
                R = return type of iteration delegate

            Params:
                args = args structure (see KeyValIterArgs and KeyIterArgs,
                       above)
                dg = iteration delegate

            Returns:
                passes through iteration delegate's return value

            Throws:
                rethrows any exceptions which occurred inside the iteration
                delegate

         **********************************************************************/

        private static R handleExceptions ( A, R ) ( ref A args, lazy R dg )
        {
            static if ( is(R == void) )
            {
                dg();
                if ( args.exception )
                {
                    throw args.exception;
                }
            }
            else
            {
                R ret = dg();
                if ( args.exception )
                {
                    throw args.exception;
                }
                return ret;
            }
        }

    }
    else static assert (false, "'tcdbforeach' does not appear to be callable, or returns void: "
                               "type is '" ~ typeof (tcdbforeach).stringof ~ '\'');

    /**************************************************************************

        tcdbforeach() callback function definitions

     **************************************************************************/

    extern (C) private static
    {
        /**********************************************************************

            tchdbforeach() callback function for key/value iteration

            Assumes that op is a pointer to a KeyValIterArgs structure and
            invokes the delegate member KeyValIterArgs.dg.

            Params:
                kbuf = key buffer
                ksiz = key length (bytes)
                vbuf = value buffer
                ksiz = value length (bytes)
                op   = custom reference; must be a pointer to a KeyValIterArgs
                       structure.

            Returns:
                true to continue or false to stop iteration

         **********************************************************************/

        bool tciter_callback_keyval ( void* kbuf, int ksiz, void* vbuf, int vsiz, void* op )
        {
            char[] key = cast (char[]) kbuf[0 .. ksiz];
            char[] val = cast (char[]) vbuf[0 .. vsiz];

            KeyValIterArgs* args = cast (KeyValIterArgs*) op;

            try
            {
                args.result = args.dg(key, val);
            }
            catch ( Exception e )
            {
                args.exception = e;
                return false;
            }

            return !args.result;
        }

        /**********************************************************************

            tchdbforeach() callback function for key iteration

            Assumes that op is a pointer to a KeyIterArgs structure and invokes
            the delegate member KeyIterArgs.dg.

            Params:
                kbuf = key buffer
                ksiz = key length (bytes)
                vbuf = value buffer
                ksiz = value length (bytes)
                op   = custom reference; must be a pointer to a KeyIterArgs
                       structure.

            Returns:
                true to continue or false to stop iteration

         **********************************************************************/

        bool tciter_callback_key ( void* kbuf, int ksiz, void* vbuf, int vsiz, void* op )
        {
            char[] key = cast (char[]) kbuf[0 .. ksiz];

            KeyIterArgs* args = cast (KeyIterArgs*) op;

            try
            {
                args.result = args.dg(key);
            }
            catch ( Exception e )
            {
                args.exception = e;
                return false;
            }

            return !args.result;
        }
    }
}
