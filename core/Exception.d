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
	
	
	/**************************************************************************

		Too Big (output buffer full)
	
	 **************************************************************************/

	static class TooBig :  IconvException
	{
		const msg = "Iconv: Too Big (output buffer full)";
		
		this ( ) { super(this.msg); }
	}
	
	

}

/******************************************************************************

    opCall template for Exception classes

*******************************************************************************/

template ExceptionOpCalls  ( E : Exception )
{
    void opCall ( char[] msg ) 
    { 
        throw new E(msg); 
    }
    
    void opCall ( char[] msg, char[] file, long line )
    {
        throw new E(msg, file, line);
    }
    
}

/******************************************************************************

	Throws exception E if ok is false or equal to 0 or a null pointer.
	
	Params:
		ok  = condition which must be true else an exception E is thrown
		msg = exception message

*******************************************************************************/

void assertEx ( E : Exception, T ) ( T ok, char[] msg )
{
	if (!ok) throw new E(msg);
}

/******************************************************************************

	Throws exception E if ok is false or equal to 0 or a null pointer.
	
	Params:
		ok  = condition which must be true else an exception E is thrown
	
*******************************************************************************/

void assertEx ( E : Exception, T ) ( T ok )
{
	if (!ok) throw new E;
}