/*******************************************************************************

    Exception for Drizzle Related errors

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Mathias Baumann

    Link with:
        -L-ldrizzle
        
*******************************************************************************/

module ocean.db.drizzle.Exception;

/*******************************************************************************

    C-Binding Imports

*******************************************************************************/

private import ocean.db.drizzle.c.constants;

/*******************************************************************************

    Drizzle Exception class

*******************************************************************************/

class DrizzleException : Exception
{                   
    /***************************************************************************

        Alias for the drizzle error that happened, if any

    ***************************************************************************/
    
    alias drizzle_return_t ErrorCode;
                   
    /***************************************************************************

        The drizzle return code that happened.
        It is one of the following values:
      
            DRIZZLE_RETURN_OK,
            DRIZZLE_RETURN_IO_WAIT,
            DRIZZLE_RETURN_PAUSE,
            DRIZZLE_RETURN_ROW_BREAK,
            DRIZZLE_RETURN_MEMORY,
            DRIZZLE_RETURN_ERRNO,
            DRIZZLE_RETURN_INTERNAL_ERROR,
            DRIZZLE_RETURN_GETADDRINFO,
            DRIZZLE_RETURN_NOT_READY,
            DRIZZLE_RETURN_BAD_PACKET_NUMBER,
            DRIZZLE_RETURN_BAD_HANDSHAKE_PACKET,
            DRIZZLE_RETURN_BAD_PACKET,
            DRIZZLE_RETURN_PROTOCOL_NOT_SUPPORTED,
            DRIZZLE_RETURN_UNEXPECTED_DATA,
            DRIZZLE_RETURN_NO_SCRAMBLE,
            DRIZZLE_RETURN_AUTH_FAILED,
            DRIZZLE_RETURN_NULL_SIZE,
            DRIZZLE_RETURN_ERROR_CODE,
            DRIZZLE_RETURN_TOO_MANY_COLUMNS,
            DRIZZLE_RETURN_ROW_END,
            DRIZZLE_RETURN_LOST_CONNECTION,
            DRIZZLE_RETURN_COULD_NOT_CONNECT,
            DRIZZLE_RETURN_NO_ACTIVE_CONNECTIONS,
            DRIZZLE_RETURN_HANDSHAKE_FAILED,
            DRIZZLE_RETURN_TIMEOUT,
            DRIZZLE_RETURN_MAX

    ***************************************************************************/

    public ErrorCode error_code;
    
    /+/***************************************************************************

        Connection where the error happened
        
        The connection can be disabled and enabled using .suspend and .resume

    ***************************************************************************/
    
    public Connection connection;+/
    
    /***************************************************************************

        Query that failed

    ***************************************************************************/
    
    public char[] query;
    
    /***************************************************************************

        Exception that was raised if it was NOT a drizzle/sql error. Else it 
        is null.

    ***************************************************************************/
    
    public Exception exception;
    
    /***************************************************************************

        Number of the connection that failed

    ***************************************************************************/
        
    public size_t connection;
    
    /***************************************************************************

        Constructor

    ***************************************************************************/
    
    public this ( )
    {
        super("");
    }
    
    /***************************************************************************

        Constructor
        
        Params:
            query      = query that failed
            code       = drizzle return code
            errString  = string representation of the error
            e          = exception that happened if it wasn't a drizzle error

    ***************************************************************************/
        
    public this ( char[] query, ErrorCode code, char[] errString, Exception e )  
    {
        super (errString);

        this.query      = query;

        this.error_code  = code;
        
        this.exception  = e;
    }
    
    /***************************************************************************

        resets the exception object to the given parameters
        
        Params:
            query     = query that failed
            code      = drizzle return code
            errString = string representation of the error
            e         = exception that happenend if it wasn't a drizzle error  

    ***************************************************************************/
      
    public DrizzleException reset ( char[] query, ErrorCode code, 
                                    char[] errString, Exception e )
    {
        this.query      = query;

        this.error_code  = code;

        this.msg        = errString;
        
        this.exception  = e;
        
        return this;
    }
        
    /***************************************************************************

        Finds out whether the error code implies an error in the connection

        DRIZZLE_RETURN_AUTH_FAILED is not really a connection error,
        but it causes the

             drizzle_state_handshake_server_read:Host '...' is blocked
             because of many connection errors; unblock with
             'mysqladmin flush-hosts'

        error which can be fixed without restarting the application,
        thus I consider it a connection error here

        Returns:
            true if the error code is a connection related problem 

    ***************************************************************************/
      
    public bool isConnectionError ( )
    {
        with (ErrorCode) switch (this.error_code)
        {
            case DRIZZLE_RETURN_LOST_CONNECTION:
            case DRIZZLE_RETURN_COULD_NOT_CONNECT:
            case DRIZZLE_RETURN_TIMEOUT:
            case DRIZZLE_RETURN_HANDSHAKE_FAILED:
            case DRIZZLE_RETURN_AUTH_FAILED:
                return true;
                
            default:
                return false;
        }
    }
}
