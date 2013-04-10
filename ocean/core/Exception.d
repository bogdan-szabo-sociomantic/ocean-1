/******************************************************************************

    Ocean Exceptions

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt & Thomas Nicolai

    Notes: Each exception class is derived from D's Exception class.

    Usage example
    ---
    import $(TITLE): HttpServerException;

    throw new HttpServerException("error");
    throw new HttpServerException("error", "myprogram.d", 1234);

    // same effect as throw new HttpServerException(...)
    HttpServerException("error");

    // same effect as throw new HttpServerException(...)
    HttpServerException("error", "myprogram.d", 1234);
    ---

    TODO: is there any reason for having all these exception types defined here
    in ocean.core, as opposed to just defining each of them in the module where
    it's used?

*******************************************************************************/

module ocean.core.Exception;

/******************************************************************************

    ArrayMapException

 ******************************************************************************/

class ArrayMapException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));

    static class NonExistingKey : ArrayMapException
    {
        this ( char[] msg ) { super(msg); }
        this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

        static mixin ExceptionOpCalls!(typeof (this));
    }
}

/******************************************************************************

    ObjectPoolException

******************************************************************************/

class ObjectPoolException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/*******************************************************************************

    UniStructException

*******************************************************************************/

class UniStructException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/*******************************************************************************

    SerializerException

*******************************************************************************/

class SerializerException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));

    /***************************************************************************

        StructSerializer Exception

    ***************************************************************************/

    static class LengthMismatch : SerializerException
    {
        size_t bytes_expected, bytes_got;

        this ( char[] msg, size_t bytes_expected, size_t bytes_got )
        {
            super(msg);

            this.bytes_expected = bytes_expected;
            this.bytes_got      = bytes_got;
        }

        this ( char[] msg, char[] file, long line,
               size_t bytes_expected, size_t bytes_go )
        {
            super(msg, file, line);

            this.bytes_expected = bytes_expected;
            this.bytes_got      = bytes_got;
        }
    }
}

/******************************************************************************

    CompressException

*******************************************************************************/

class CompressException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    HMAC Exception

*******************************************************************************/

class HMACException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    MySQLException

*******************************************************************************/

class MySQLException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    SqliteException

*******************************************************************************/

class SqliteException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    TokyoCabinetException

*******************************************************************************/

class TokyoCabinetException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));

    static class Cursor : TokyoCabinetException
    {
        this ( char[] msg ) { super(msg); }
        this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

        static mixin ExceptionOpCalls!(typeof (this));
    }
}

/******************************************************************************

    SphinxException

*******************************************************************************/

class SphinxException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    UrlException

*******************************************************************************/

class UrlException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    HttpResponseException

*******************************************************************************/

class HttpResponseException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    HttpServerException

*******************************************************************************/

class HttpServerException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    CurlException

*******************************************************************************/

class CurlException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    NgramParserException

*******************************************************************************/

class NgramParserException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    PCREException

*******************************************************************************/

class PCREException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    ConfigException

*******************************************************************************/

class ConfigException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    JsonException

*******************************************************************************/

class JsonException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    IconvException

*******************************************************************************/

class IconvException : Exception
{
    const MSG = "Iconv: Error";

    this ( char[] msg = MSG ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

    static mixin ExceptionOpCalls!(typeof (this));

    /**************************************************************************

        Invalid Multibyte Sequence

     **************************************************************************/

    static class InvalidMbSeq :  IconvException
    {
        const msg = "Iconv: Invalid Multibyte Sequence";

        this ( ) { super(this.msg); }
    }

    /**************************************************************************

        Incomplete Multibyte Sequence

     **************************************************************************/

    static class IncompleteMbSeq :  IconvException
    {
        const msg = "Iconv: Incomplete Multibyte Sequence";

        this ( ) { super(this.msg); }
    }
}

/******************************************************************************

    opCall template for Exception classes

*******************************************************************************/

template ExceptionOpCalls  ( E : Exception )
{
    void opCall ( Args ... ) ( Args args )
    {
        throw new E(args);
    }
}

/******************************************************************************

    CustomException template to mixin an Exception class into a class or struct.

    Note: requires the concat function, defined in ocean.core.Array, so you need
    to import that module into any module where you use this mixin:

        private import ocean.core.Array;

    Usage:

    import $(TITLE);

    ---
        class MyClass
        {
            // ...

            static mixin CustomException!();

            // Now MyClass.Exception can be thrown and caught.
        }
    ---

 *******************************************************************************/

template CustomException ( )
{
    alias .Exception _Exception;

    class Exception : _Exception
    {
        this ( )                                    { super(""); }
        this ( char[] msg                         ) { super(msg); }
        this ( char[] msg, char[] file, long line ) { super(msg, file, line); }

        typeof(this) opCall ( char[][] msg ... )
        {
            super.msg.concat(msg);
            return this;
        }
    }
}

/******************************************************************************

    Throws an existing Exception if ok is false, 0 or null.

    Params:
        ok = condition which is challenged for being true or not 0/null
        e  = Exception instance to throw or expression returning that instance.

    Throws:
        e if ok is
            - false or
            - equal to 0 or
            - a null object, reference or pointer.

 ******************************************************************************/

void assertEx ( E : Exception = Exception, T ) ( T ok, lazy E e )
{
    if (!ok) throw e;
}

/******************************************************************************

    Throws a new Exception if ok is false, 0 or null.

    Params:
        ok = condition which is challenged for being true or not 0/null

    Throws:
        new E if ok is
            - false or
            - equal to 0 or
            - a null object, reference or pointer.

 ******************************************************************************/

void assertEx ( E : Exception = Exception, T ) ( T ok )
{
    if (!ok) throw new E;
}


/******************************************************************************

    Throws exception E if ok is false or equal to 0 or a null object, reference
    or pointer.

    Params:
        ok   = condition which must be true else an exception E is thrown
        msg  = message to pass to exception constructor
        args = additional exception arguments, depending on the particular
               exception

*******************************************************************************/

void assertEx ( E : Exception = Exception, T, Args ... ) ( T ok, lazy char[] msg, Args args )
{
    if (!ok) throw new E(msg, args);
}

