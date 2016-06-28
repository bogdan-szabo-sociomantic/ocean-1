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

import ocean.transition;

import ocean.core.Array: copy, concat;
import ocean.core.Enforce;
import ocean.core.Exception;
import ocean.net.http.consts.StatusCodes;

import ocean.net.http.HttpConst: HttpResponseCode;


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

    public typeof (this) set (HttpResponseCode code, istring file = __FILE__,
                              typeof(__LINE__) line = __LINE__)
    {
        this.status = cast(StatusCode) code;
        return this.set(this.status_phrase, file, line);
    }

    istring status_phrase ( )
    {
        return StatusPhrases[this.status];
    }

    /***************************************************************************

        Custom enforce for using an HTTP status code together with a set of
        messages that should be appended.

        Template_Params:
            file = The filename
            line = The line number
            T = Types of messages to append

        Params:
            ok = The condition to enforce
            code = The status code
            messages = The messages

    ***************************************************************************/

    public void enforce ( istring file = __FILE__, long line = __LINE__, T ... )
                        ( bool ok, HttpResponseCode code, T messages )
    {
        if ( !ok )
        {
            this.set(code, file, line);

            foreach ( msg; messages )
            {
                this.append(" ");
                this.append(msg);
            }

            throw this;
        }
    }

    version ( UnitTest )
    {
        import ocean.core.Test;
    }

    unittest
    {
        auto e = new HttpException();

        e.enforce(true, StatusCode.OK);

        try
        {
            e.enforce(false, StatusCode.OK, "Invalid resource");
        }
        catch
        {
            test!("==")(e.status, StatusCode.OK);
            test!("==")(getMsg(e), "Ok Invalid resource");
        }

        try
        {
            auto path = "/path/with/errors";
            e.enforce(false, StatusCode.NotFound, "Unable to locate URI path:", path);
        }
        catch
        {
            test!("==")(e.status, StatusCode.NotFound);
            test!("==")(getMsg(e), "Not Found Unable to locate URI path: /path/with/errors");
        }
    }
}


/******************************************************************************/

class HttpParseException : HttpException {}


/******************************************************************************/

class HeaderParameterException : HttpServerException {}
