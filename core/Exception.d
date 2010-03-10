/******************************************************************************

    Ocean exception classes

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        March 2010: Initial release

    authors:        David Eckardt
    
    Notes: Each exception class is derived from D's Exception class.
    
    Usage:
    
    ---
    
        import $(TITLE): HttpServerException;
        
        throw new HttpServerException("error");
        throw new HttpServerException("error", "myprogram.d", 1234);
        
        HttpServerException("error");                       // same effect as 'throw new HttpServerException(...)' 
        HttpServerException("error", "myprogram.d", 1234);  // same effect as 'throw new HttpServerException(...)' 
    
    ---
    
 ******************************************************************************/

module ocean.core.Exception;


/******************************************************************************

    CompressException

 ******************************************************************************/

class CompressException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    MySQLException

 ******************************************************************************/

class MySQLException : Exception
{
    this ( char[] msg ) { super(msg); } 
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}



/******************************************************************************

    SqliteException

 ******************************************************************************/

class SqliteException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    TokyoCabinetException

 ******************************************************************************/

class TokyoCabinetException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    PersistentQueueException

 ******************************************************************************/

class PersistentQueueException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    SphinxException

 ******************************************************************************/

class SphinxException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    TokyoTyrantException

 ******************************************************************************/

class TokyoTyrantException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}


/******************************************************************************

    HttpQueryParamsException

 ******************************************************************************/

class HttpQueryParamsException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}


/******************************************************************************

    HttpResponseException

 ******************************************************************************/

class HttpResponseException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}


/******************************************************************************

    HttpServerException

 ******************************************************************************/

class HttpServerException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    GoogleException

 ******************************************************************************/

class GoogleException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    LiveException

 ******************************************************************************/

class LiveException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    WikipediaCategorizerException

 ******************************************************************************/

class WikipediaCategorizerException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    CurlException

 ******************************************************************************/

class CurlException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    NgramParserException

 ******************************************************************************/

class NgramParserException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    PCREException

 ******************************************************************************/

class PCREException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    ConfigException

 ******************************************************************************/

class ConfigException : Exception
{
    this ( char[] msg ) { super(msg); }
    this ( char[] msg, char[] file, long line ) { super(msg, file, line); }
    
    static mixin ExceptionOpCalls!(typeof (this));
}

/******************************************************************************

    opCall template for Exception classes

 ******************************************************************************/

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
