/*******************************************************************************

    Result Class. Provides functions and iterators for accessing the
    resulting data of a query

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

    Link with:
        -L-ldrizzle

*******************************************************************************/

module ocean.db.drizzle.Result;

/*******************************************************************************

    Private Imports from the C Binding

*******************************************************************************/

private import ocean.db.drizzle.c.drizzle;

private import ocean.db.drizzle.c.conn;

private import ocean.db.drizzle.c.result;

private import ocean.db.drizzle.c.structs;

private import ocean.db.drizzle.c.field_client;

private import ocean.db.drizzle.c.column_client;

private import ocean.db.drizzle.c.result_client;

private import ocean.db.drizzle.c.row_client;

public import ocean.db.drizzle.Exception;

/*******************************************************************************

    Other Private imports

*******************************************************************************/

debug private import ocean.util.log.Trace;

private import tango.core.Thread : Fiber;

private import tango.stdc.stringz;

/*******************************************************************************

    Checks the given drizzle return code for whether more data is needed or
    not. If more data is needed, calls Yield() and returns true for more data

    Params:
        code = the return code of the drizzle function

    Returns:
        true when the drizzle function that produced the given error code
        should be called again

*******************************************************************************/

private static bool more ( drizzle_return_t code )
{
    if (code == drizzle_return_t.DRIZZLE_RETURN_IO_WAIT)
    {
        Fiber.yield();
        return true;
    }

    return false;
}

/*******************************************************************************

    Result class. Provides functions and iterators to access the result data

*******************************************************************************/

class Result
{
    /***************************************************************************

        Local reusable exception.

    ***************************************************************************/

    private DrizzleException exception;

    /***************************************************************************

        Local reusable row struct.

    ***************************************************************************/

    private Row rowIterator;

    /***************************************************************************

        Original Query, available for exception throwing

    ***************************************************************************/

    package char[] query;

    /***************************************************************************

        Drizzle result instance

    ***************************************************************************/

    package drizzle_result_st result = void;

    /***************************************************************************

        Each result needs to be processed. If opApply wasn't called it wasn't
        processed and will error for the next query. On reset, we make
        sure it has been processed.

    ***************************************************************************/

    bool processed = false;

    /***************************************************************************

        Pointer to drizzle connection instance

    ***************************************************************************/

    private drizzle_con_st* connection;

    /***********************************************************************

        Resizable buffer. Will be resized to fit the required length.
        Only used when fields are > 1024 bytes

    ***********************************************************************/

    private char[] dynamicBuffer;

    /***************************************************************************

        Row struct for iterating over the fields of a row.

    ***************************************************************************/

    private struct Row
    {
        /***********************************************************************

            Reference to the outer Result instance

        ***********************************************************************/

        private Result result;

        /***********************************************************************

            Whether this row already was completely processed or not.
            Used by Result.opApply to skip unprocessed rows

        ***********************************************************************/

        private bool processed = false;

        /***********************************************************************

            Sets a buffer that is to be used for fields > 1024 bytes.
            The buffer will be resized dynamically to fit the required
            length

            Params:
                buffer = user buffer to be used

        ***********************************************************************/

        public void setBuffer ( char[] buffer )
        {
            this.result.dynamicBuffer = buffer;
        }

        /***********************************************************************

            Field Iterator with counter

            Params:
                dg = delegate to be called for each field

        ***********************************************************************/

        int opApply ( int delegate ( ref size_t , ref char[] field ) dg )
        {
            size_t i = 0;

            int result;

            foreach (row; *this)
            {
                result = dg(i, row);

                if (result)
                {
                    break;
                }

                i++;
            }

            return result;
        }

        /***********************************************************************

            Field Iterator.

            Reads the fields directly from the socket buffer and thus rarely
            needs any additional buffer.

            For cases when fields are incomplete it uses an internal
            stack-buffer (1024 bytes) which should be sufficient for
            most cases.

            If you expect to read fields larger than 1024 bytes, you should
            set your own buffer using setBuffer to the according size.

            If a field is larger than 1024 bytes the library will dynamically
            allocate the needed buffer or uses (and adjusts) the one set
            by setBuffer.

            Params:
                dg = delegate to be called for each field

        ***********************************************************************/

        int opApply ( int delegate ( ref char[] field ) dg )
        {
            char[1024] stackBuffer;
            char[]     buffer = stackBuffer;
            bool       bufferUsed = false;
            char*      fieldPtr;
            size_t     fieldLen;
            size_t     totalLen;
            size_t     offset;
            drizzle_return_t returnCode;

            bool read_field ()
            {
                bufferUsed = false;

                do
                {
                    do fieldPtr = drizzle_field_read(&this.result.result, &offset,
                                                     &fieldLen, &totalLen, &returnCode);
                    while (more(returnCode));

                    if (returnCode == drizzle_return_t.DRIZZLE_RETURN_ROW_END)
                    {
                        return false;
                    }

                    this.result.check(returnCode);

                    if (totalLen != fieldLen)
                    {
                        bufferUsed = true;

                        if (totalLen >= stackBuffer.length)
                        {
                            if ( this.result.dynamicBuffer.length < totalLen )
                            {
                                debug ( Drizzle ) Trace.formatln("Resizing dynamic buffer from {}", this.result.dynamicBuffer.length);
                                this.result.dynamicBuffer.length = totalLen;
                            }
                            buffer = this.result.dynamicBuffer;
                            debug ( Drizzle ) Trace.formatln("Using dynamicBuffer");
                        }

                        debug ( Drizzle ) Trace.formatln("Using Buffer: totalLen: {} fieldLen: {}"
                                        " offset: {}", totalLen, fieldLen,
                                        offset);

                        buffer[offset .. offset + fieldLen] = fieldPtr[0 .. fieldLen];
                    }
                }
                while (offset + fieldLen < totalLen)

                return true;
            }

            int    result = 0;
            char[] field;

            Exception exc;

            while (read_field())
            {
                field = bufferUsed ? buffer[0 .. totalLen] :
                                     fieldPtr[0..fieldLen];

                try if (result == 0) result = dg(field);
                catch (Exception e)
                {
                    exc = e;
                    result = 1;
                }
            }


            this.processed = true;

            if (exc !is null) throw exc;

            return result;
        }
    }

    /***************************************************************************

        Row Iterator. Iterates over Rows.

        Params:
            dg = delegate that will be called for each Row

    ***************************************************************************/

    public int opApply ( int delegate ( ref Row ) dg )
    {
        drizzle_return_t returnCode;
        ulong            row;
        int              result = 0;

        ushort real_columns = drizzle_result_column_count(&this.result);

        if (real_columns > 0)
        {
            do returnCode = drizzle_column_skip(&this.result);
            while (more(returnCode));

            check(returnCode);

            ulong read_row ()
            {
                do row = drizzle_row_read(&this.result, &returnCode);
                while (more(returnCode));

                check(returnCode);

                return row;
            }

            while ((row = read_row()) != 0)
            {
                this.rowIterator.processed = false;

                if (result == 0) result = dg(this.rowIterator);

                if (!this.rowIterator.processed)
                {
                    foreach (r; this.rowIterator) {};
                }
            }
        }

        this.processed = true;

        return result;
    }

    /***************************************************************************

        Constructor

        Params:
            connection = pointer to the drizzle connection instance

    ***************************************************************************/

    package this ( drizzle_con_st* connection )
    {
        this.connection = connection;
        this.rowIterator.result = this;
    }

    /***************************************************************************

        Check. Checks whether the given return code is OK and optionally
        throws an exception if not or returns false

        Params:
            returnCode = the drizzle code to check for OK
            throw_     = whether to throw an exception describing the error
                         if returnCode is not okay

        Returns:
            true if everything is okay, else false

    ***************************************************************************/

    private bool check ( drizzle_return_t returnCode, bool throw_ = true)
    {
        if (returnCode != drizzle_return_t.DRIZZLE_RETURN_OK)
        {
            if (throw_)
            {
                if (!exception)
                {
                    exception = new DrizzleException;
                }
                auto e = exception.reset(query, returnCode,
                            fromStringz(
                                drizzle_error(
                                    drizzle_con_drizzle(
                                        drizzle_result_drizzle_con(
                                            &this.result)))), null);

                throw e;
            }
            else
            {
                return false;
            }
        }

        return true;
    }

    /***************************************************************************

        Resets the result object, making it ready for the next use.

        Should only be called if no errors happenend

    ***************************************************************************/

    package void reset()
    {
        if (!processed)
        {
            foreach (row; this) {};
        }

        drizzle_result_free(&this.result);
    }
}

