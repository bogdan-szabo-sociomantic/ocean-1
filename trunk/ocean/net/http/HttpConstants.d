/*******************************************************************************

    HTTP Constants that are not defined in tango.net.http.HttpConst

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        April 2009: Initial release

    authors:        Lars Kirchhoff, Thomas Nicolai & David Eckhardt

*******************************************************************************/

module      ocean.net.http.HttpConstants;


/*******************************************************************************

    Imports

*******************************************************************************/

public  import      tango.net.http.HttpConst;


/*******************************************************************************

    Http Request Types

********************************************************************************/


struct HttpMethod
{
    static const char[] Options      = `OPTIONS`;
    static const char[] Get          = `GET`;
    static const char[] Head         = `HEAD`;
    static const char[] Post         = `POST`;
    static const char[] Put          = `PUT`;
    static const char[] Delete       = `DELETE`;
    static const char[] Trace        = `TRACE`;
    static const char[] Connect      = `CONNECT`;
}


/*******************************************************************************

    Uri Delimiter

********************************************************************************/


struct UriDelim
{
    static const char[] QUERY      = `?`; // seperates uri path & query parameter
    static const char[] FRAGMENT   = `#`; // seperates uri path & fragment
    static const char[] QUERY_URL  = `/`; // separates url path elements
    static const char[] PARAM      = `&`; // seperates key/value pairs
    static const char[] KEY_VALUE  = `=`; // separate key and value
}


/*******************************************************************************

    Http Protocol Version

    The type definition is an easy means to avoid inadvertent use of an
    arbitrary string where a HTTP version identifier string is required.

********************************************************************************/

typedef char[] HttpVersionId;

struct HttpVersion
{
    static const HttpVersionId v10 = cast (HttpVersionId) `HTTP/1.0`,
                               v11 = cast (HttpVersionId) `HTTP/1.1`;
}


/*******************************************************************************

    Http Header & Query Seperators

********************************************************************************/


const       char[]      HttpHeaderSeparator    = HttpConst.Eol ~ HttpConst.Eol;
const       char[]      HttpQueryLineSeparator = HttpConst.Eol;


struct HttpCookieAttr
{
    static const struct Name
    {
        static const Comment  = `comment`,
                     Domain   = `domain`,
                     Expires  = `expires`, // max-age !is crossbrowser compatible
                     Path     = `path`,
                     Secure   = `secure`,
                     Version  = `version`;
    }

    static const struct Delim
    {
        static const AttrValue  = '=',
                     Attributes = ';';
    }
}

/*******************************************************************************

    Http Status Description strings

********************************************************************************/


struct HttpStatusNames
{
    /**************************************************************************

        Returns a HTTP status code description string.

        Params:
            code = HTTP status code

        Returns:
            HTTP status code description string

     **************************************************************************/

    public static char[] opIndex ( int code )
    {
        char[]* str = code in this.response_names;

        return str? *str : `[unknown HTTP status code]`;
    }

    /**************************************************************************

        Tells whether a description string is available for a HTTP status code.

        Params:
            code = HTTP status code

        Returns:
            true if there is a description string or false otherwise

     **************************************************************************/

    public static bool opIn ( int code )
    {
        return !!(code in this.response_names);
    }

    /**************************************************************************

        Description strings database

     **************************************************************************/

    private static char[][int] response_names;

    /**************************************************************************

        Static constructor; fills the database

     **************************************************************************/

    static this ( )
    {
        foreach (status;
        [
            HttpResponses.Continue,
            HttpResponses.SwitchingProtocols,
            HttpResponses.OK,
            HttpResponses.Created,
            HttpResponses.Accepted,
            HttpResponses.NonAuthoritativeInformation,
            HttpResponses.NoContent,
            HttpResponses.ResetContent,
            HttpResponses.PartialContent,
            HttpResponses.MultipleChoices,
            HttpResponses.MovedPermanently,
            HttpResponses.Found,
            HttpResponses.SeeOther,
            HttpResponses.NotModified,
            HttpResponses.UseProxy,
            HttpResponses.TemporaryRedirect,
            HttpResponses.BadRequest,
            HttpResponses.Unauthorized,
            HttpResponses.PaymentRequired,
            HttpResponses.Forbidden,
            HttpResponses.NotFound,
            HttpResponses.MethodNotAllowed,
            HttpResponses.NotAcceptable,
            HttpResponses.ProxyAuthenticationRequired,
            HttpResponses.RequestTimeout,
            HttpResponses.Conflict,
            HttpResponses.Gone,
            HttpResponses.LengthRequired,
            HttpResponses.PreconditionFailed,
            HttpResponses.RequestEntityTooLarge,
            HttpResponses.RequestURITooLarge,
            HttpResponses.UnsupportedMediaType,
            HttpResponses.RequestedRangeNotSatisfiable,
            HttpResponses.ExpectationFailed,
            HttpResponses.InternalServerError,
            HttpResponses.NotImplemented,
            HttpResponses.BadGateway,
            HttpResponses.ServiceUnavailable,
            HttpResponses.GatewayTimeout,
            HttpResponses.VersionNotSupported
        ])
        {
            this.response_names[status.code] = status.name;
        }
    }
}



