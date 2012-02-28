/*******************************************************************************

    copyright:      Copyright (c) 2012 sociomantic labs. All rights reserved

    version:        23/02/2012: Initial release

    authors:        Gavin Norman

    HTTP response code parser and getter.

    Designed to work with a curl process using the -w "%{http_code}" option,
    where the last 3 bytes of the received stdout stream will be the HTTP
    response code from the server. These 3 bytes are parsed and converted into
    an enum / description.

*******************************************************************************/

module ocean.net.client.curl.process.HttpResponse;



/*******************************************************************************

    Imports

*******************************************************************************/

private import Integer = tango.text.convert.Integer;

private import ocean.core.SmartEnum;

debug private import ocean.io.Stdout;



/*******************************************************************************

    Struct for parsing http response status codes from curl's stdout stream.

*******************************************************************************/

public struct HttpResponse
{
    /***************************************************************************

        Smart enum for status codes / description strings.

    ***************************************************************************/

    private alias SmartEnumValue!(int) CodeDesc;

    public mixin(SmartEnum!("Code",
        CodeDesc("Invalid", -1),
        CodeDesc("Continue", 100),
        CodeDesc("SwitchingProtocols", 101),
        CodeDesc("Ok", 200),
        CodeDesc("Created", 201),
        CodeDesc("Accepted", 202),
        CodeDesc("NonAuthoritativeInformation", 203),
        CodeDesc("NoContent", 204),
        CodeDesc("ResetContent", 205),
        CodeDesc("PartialContent", 206),
        CodeDesc("MultipleChoices", 300),
        CodeDesc("MovedPermanently", 301),
        CodeDesc("Found", 302),
        CodeDesc("SeeOther", 303),
        CodeDesc("NotModified", 304),
        CodeDesc("UseProxy", 305),
        CodeDesc("TemporaryRedirect", 307),
        CodeDesc("BadRequest", 400),
        CodeDesc("Unauthorized", 401),
        CodeDesc("PaymentRequired", 402),
        CodeDesc("Forbidden", 403),
        CodeDesc("NotFound", 404),
        CodeDesc("MethodNotAllowed", 405),
        CodeDesc("NotAcceptable", 406),
        CodeDesc("ProxyAuthenticationRequired", 407),
        CodeDesc("RequestTimeout", 408),
        CodeDesc("Conflict", 409),
        CodeDesc("Gone", 410),
        CodeDesc("LengthRequired", 411),
        CodeDesc("PreconditionFailed", 412),
        CodeDesc("RequestEntityTooLarge", 413),
        CodeDesc("RequestURITooLarge", 414),
        CodeDesc("UnsupportedMediaType", 415),
        CodeDesc("RequestedRangeNotSatisfiable", 416),
        CodeDesc("ExpectationFailed", 417),
        CodeDesc("InternalServerError", 500),
        CodeDesc("NotImplemented", 501),
        CodeDesc("BadGateway", 502),
        CodeDesc("ServiceUnavailable", 503),
        CodeDesc("GatewayTimeout", 504),
        CodeDesc("HTTPVersionNotSupported", 505)
    ));


    /***************************************************************************

        Static array of three bytes, to store status code.

    ***************************************************************************/

    private const status_bytes = 3;

    private ubyte[status_bytes] response;


    /***************************************************************************

        Resets the internal status code to the defautl (-1 : invalid).

    ***************************************************************************/

    public void reset ( )
    {
        this.response[] = cast(ubyte[])" -1";
    }


    /***************************************************************************

        Updates the status code bytes from a stream of incoming data. The last
        3 bytes received from the stream are stored.

        Params:
            data = chunk of data received from stream

    ***************************************************************************/

    public void update ( ubyte[] data )
    {
        if ( data.length == 0 )
        {
            return;
        }
        if ( data.length >= this.status_bytes + 1 )
        {
            this.response[] = data[$ - (this.status_bytes+1) .. $-1];
        }
        else
        {
            // Shift existing bytes.
            auto copy_bytes = this.status_bytes - data.length;
            for ( int i = 0; i < copy_bytes; i++ )
            {
                this.response[i] = this.response[i + data.length];
            }

            // Insert new bytes at end.
            this.response[$-data.length .. $-1] = data[$-data.length .. $-1];
        }
    }


    /***************************************************************************

        Parses the received 3 bytes of data and returns the appropriate HTTP
        response code.

        Returns:
            status code (possibly -1 / Invalid)

    ***************************************************************************/

    public Code.BaseType code ( )
    {
		// Avoid errors if it didn't receive anything at all
		if ( this.response[0] < '0' || this.response[0] > '9' )
		{
			return Code.Invalid;
		}
		
        int integer = Integer.toLong(this.response);
        if ( Code.description(integer) !is null )
        {
            return integer;
        }
        else
        {
            return Code.Invalid;
        }
    }
}

