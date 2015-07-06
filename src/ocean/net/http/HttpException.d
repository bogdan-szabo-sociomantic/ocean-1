/*******************************************************************************

    HTTP exception classes

    - HttpServerException is the base class.
    - HttpException is thrown when a request cannot be fulfilled to abort
      request processing and immediately send the response. It contains the HTTP
      response status code to send.
    - HttpParseException is thrown on HTTP request or response message parse
      error.
    - HeaderParameterException is thrown when a required HTTP message header
      parameter is missing or contains an invalid value.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

*******************************************************************************/

module ocean.net.http.HttpException;

/******************************************************************************

    Imports

 ******************************************************************************/

import ocean.core.Array: copy, concat;
import ocean.core.Exception;
import ocean.net.http.consts.StatusCodes;

import tango.core.Enforce;
import tango.net.http.HttpConst: HttpResponseCode;


/******************************************************************************/

class HttpServerException : Exception
{
    mixin ReusableExceptionImplementation;
}


/******************************************************************************/

class HttpException : HttpServerException
{
    public StatusCode status;

    public override typeof (this) set ( cstring msg, istring file = __FILE__,
                                        long line = __LINE__ )
    {
        super.set(msg, file, line);
        return this;
    }

    public typeof (this) set (StatusCode code, istring file = __FILE__,
                              typeof(__LINE__) line = __LINE__)
    {
        this.status = code;
        return this.set(this.status_phrase, file, line);
    }

    istring status_phrase ( )
    {
        return StatusPhrases[this.status];
    }
}


/******************************************************************************/

class HttpParseException : HttpException {}


/******************************************************************************/

class HeaderParameterException : HttpServerException {}
