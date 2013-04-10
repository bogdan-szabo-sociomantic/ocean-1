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

    protected void set ( char[] file, typeof (__LINE__) line, T ... ) ( T msg )
    {
        super.file = file;
        super.line = line;

        .concat(super.msg, msg);
    }

    protected void set ( T ... ) ( T msg )
    {
        .concat(super.msg, msg);
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    protected override void dispose ( )
    {
        delete super.msg;
    }
}

/******************************************************************************/

class HttpException : HttpServerException
{
    StatusCode status;

    void assertEx ( char[] file, typeof (__LINE__) line, T, U ... ) ( T ok, HttpResponseCode status, U msg )
    {
        if (!ok) throw this.opCall!(file, line, U)(status, msg);
    }

    void assertEx ( T, U ... ) ( T ok, HttpResponseCode status, U msg )
    {
        if (!ok) throw this.opCall(status, msg);
    }

    typeof (this) opCall ( char[] file, typeof (__LINE__) line, T ... ) ( HttpResponseCode status, T msg )
    {
        this.status = cast (StatusCode) status;

        super.set!(file, line, T)(msg);

        return this;
    }

    typeof (this) opCall ( T ... ) ( HttpResponseCode status, T msg )
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
    void assertEx ( char[] file, typeof (__LINE__) line, T, U ... ) ( T ok, U msg )
    {
        if (!ok) throw this.opCall!(file, line, U)(msg);
    }

    void assertEx ( T, U ... ) ( T ok, U msg )
    {
        if (!ok) throw this.opCall(msg);
    }

    typeof (this) opCall ( char[] file, typeof (__LINE__) line, T ... ) ( T msg )
    {
        super.opCall!(file, line, T)(super.status.BadRequest, msg);

        return this;
    }

    typeof (this) opCall ( T ... ) ( T msg )
    {
        super.opCall(super.status.BadRequest, msg);

        return this;
    }

}

/******************************************************************************/

class HeaderParameterException : HttpServerException
{
    char[] header_field_name;

    void assertEx ( char[] file, typeof (__LINE__) line, T, U ... ) ( T ok, char[] header_field_name, U msg )
    {
        if (!ok) throw this.opCall!(file, line, U)(header_field_name, msg);
    }

    void assertEx ( T, U ... ) ( T ok, char[] header_field_name, U msg )
    {
        if (!ok) throw this.opCall(header_field_name, msg);
    }

    typeof (this) opCall ( char[] file, typeof (__LINE__) line, T ... ) ( char[] header_field_name, T msg )
    {
        this.header_field_name.copy(header_field_name);
        super.set!(file, line, T)(msg);
        return this;
    }

    typeof (this) opCall ( T ... ) ( char[] header_field_name, T msg )
    {
        this.header_field_name.copy(header_field_name);
        super.set(msg);
        return this;
    }
}
