/******************************************************************************

    HTTP exception classes
    
    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved
    
    version:        May 2011: Initial release
    
    author:         David Eckardt
    
    - HttpServerException is the base class.
    - HttpException is thrown when a request cannot be fulfilled to abort
      request processing and immediately send the response. It contains the HTTP
      response status code to send. 
    - HttpParseException is thrown on HTTP request or response message parse
      error.
    - HeaderParameterException is thrown when a required HTTP message header
      parameter is missing or contains an invalid value.
    
 ******************************************************************************/

module ocean.net.http2.HttpException;

/******************************************************************************

    Imports

 ******************************************************************************/

private import ocean.net.http2.consts.StatusCodes;

private import tango.net.http.HttpConst: HttpResponseCode;

private import ocean.core.Array: copy, concat;

/******************************************************************************/

class HttpServerException : Exception
{
    this ( ) {super("");}
    
    protected void set ( char[] file, long line, char[][] msg ... )
    {
        super.file.copy(file);
        super.line = line;
        this.set(msg);
    }
    
    protected void set ( char[][] msg ... )
    {
        super.msg.concat(msg);
    }
}

/******************************************************************************/

class HttpException : HttpServerException
{
    StatusCode status;
    
    void assertEx ( T ) ( T ok, char[] file, long line, HttpResponseCode status, char[][] msg ... )
    {
        if (!ok) throw this.opCall(file, line, status, msg);
    }
    
    void assertEx ( T ) ( T ok, HttpResponseCode status, char[][] msg ... )
    {
        if (!ok) throw this.opCall(status, msg);
    }
    
    typeof (this) opCall ( char[] file, long line, HttpResponseCode status, char[][] msg ... )
    {
        this.status = cast (StatusCode) status;
        
        super.set(file, line, msg);
        
        return this;
    }
    
    typeof (this) opCall ( HttpResponseCode status, char[][] msg ... )
    {
        this.status = cast (StatusCode) status;
        
        super.set(msg);
        
        return this;
    }
    
    char[] status_phrase ( )
    {
        return StatusPhrases[this.status];
    }
}

/******************************************************************************/

class HttpParseException : HttpException
{
    void assertEx ( T ) ( T ok, char[] file, long line, char[][] msg ... )
    {
        if (!ok) throw this.opCall(file, line, msg);
    }
    
    void assertEx ( T ) ( T ok, char[][] msg ... )
    {
        if (!ok) throw this.opCall(msg);
    }
    
    typeof (this) opCall ( char[] file, long line, char[][] msg ... )
    {
        super.opCall(file, line, super.status.BadRequest, msg);
        
        return this;
    }
    
    typeof (this) opCall ( char[][] msg ... )
    {
        super.opCall(super.status.BadRequest, msg);
        
        return this;
    }

}

/******************************************************************************/

class HeaderParameterException : HttpServerException
{
    char[] header_field_name;
    
    void assertEx ( T ) ( T ok, char[] header_field_name, char[] file, long line, char[][] msg ... )
    {
        if (!ok) throw this.opCall(header_field_name, file, line, msg);
    }
    
    void assertEx ( T ) ( T ok, char[] header_field_name, char[][] msg ... )
    {
        if (!ok) throw this.opCall(header_field_name, msg);
    }
    
    typeof (this) opCall ( char[] header_field_name, char[] file, long line, char[][] msg ... )
    {
        this.header_field_name.copy(header_field_name);
        super.set(file, line, msg);
        return this;
    }
    
    typeof (this) opCall ( char[] header_field_name, char[][] msg ... )
    {
        this.header_field_name.copy(header_field_name);
        super.set(msg);
        return this;
    }
}
