/******************************************************************************

    HTTP status codes and reason phrases

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    author:         David Eckardt

    @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html

 ******************************************************************************/

module ocean.net.http.consts.StatusCodes;

/******************************************************************************

    Imports

 ******************************************************************************/

private import tango.net.http.HttpConst: HttpHeader, HttpResponseCode;

/******************************************************************************

    Status code enumerator redefinition to make OK the default/initial value

 ******************************************************************************/

typedef HttpResponseCode StatusCode = HttpResponseCode.OK;

/******************************************************************************

    Status phrase string definitions and code association

 ******************************************************************************/

struct StatusPhrases
{
    struct HttpStatusPhrase
    {
        HttpResponseCode status_code;
        char[]           reason_phrase;
    }

    /**************************************************************************

        The officially recommended reason phrases for the status codes

        @see http://www.w3.org/Protocols/rfc2616/rfc2616-sec6.html#sec6.1.1

     **************************************************************************/

    const HttpStatusPhrase[] StatusReasonPhrases =
    [
        HttpStatusPhrase(HttpResponseCode.Continue,                     "Continue"),
        HttpStatusPhrase(HttpResponseCode.SwitchingProtocols,           "Switching Protocols"),
        HttpStatusPhrase(HttpResponseCode.OK,                           "Ok"),
        HttpStatusPhrase(HttpResponseCode.Created,                      "Created"),
        HttpStatusPhrase(HttpResponseCode.Accepted,                     "Accepted"),
        HttpStatusPhrase(HttpResponseCode.NonAuthoritativeInformation,  "Non-Authoritative Information"),
        HttpStatusPhrase(HttpResponseCode.NoContent,                    "No Content"),
        HttpStatusPhrase(HttpResponseCode.ResetContent,                 "Reset Content"),
        HttpStatusPhrase(HttpResponseCode.PartialContent,               "Partial Content"),
        HttpStatusPhrase(HttpResponseCode.MultipleChoices,              "Multiple Choices"),
        HttpStatusPhrase(HttpResponseCode.MovedPermanently,             "Moved Permanently"),
        HttpStatusPhrase(HttpResponseCode.Found,                        "Found"),
        HttpStatusPhrase(HttpResponseCode.SeeOther,                     "See Other"),
        HttpStatusPhrase(HttpResponseCode.NotModified,                  "Not Modified"),
        HttpStatusPhrase(HttpResponseCode.UseProxy,                     "Use Proxy"),
        HttpStatusPhrase(HttpResponseCode.TemporaryRedirect,            "Temporary Redirect"),
        HttpStatusPhrase(HttpResponseCode.BadRequest,                   "Bad Request"),
        HttpStatusPhrase(HttpResponseCode.Unauthorized,                 "Unauthorized"),
        HttpStatusPhrase(HttpResponseCode.PaymentRequired,              "$$$ Payment Required $$$"),
        HttpStatusPhrase(HttpResponseCode.Forbidden,                    "Forbidden"),
        HttpStatusPhrase(HttpResponseCode.NotFound,                     "Not Found"),
        HttpStatusPhrase(HttpResponseCode.MethodNotAllowed,             "Method Not Allowed"),
        HttpStatusPhrase(HttpResponseCode.NotAcceptable,                "Not Acceptable"),
        HttpStatusPhrase(HttpResponseCode.ProxyAuthenticationRequired,  "Proxy Authentication Requred"),
        HttpStatusPhrase(HttpResponseCode.RequestTimeout,               "Request Timeout"),
        HttpStatusPhrase(HttpResponseCode.Conflict,                     "Conflict"),
        HttpStatusPhrase(HttpResponseCode.Gone,                         "Gone"),
        HttpStatusPhrase(HttpResponseCode.LengthRequired,               "Length Required"),
        HttpStatusPhrase(HttpResponseCode.PreconditionFailed,           "Precondition Failed"),
        HttpStatusPhrase(HttpResponseCode.RequestEntityTooLarge,        "Request Entity Too Large"),
        HttpStatusPhrase(HttpResponseCode.RequestURITooLarge,           "Request-URI Too Long"),
        HttpStatusPhrase(HttpResponseCode.UnsupportedMediaType,         "Unsupported Media Type"),
        HttpStatusPhrase(HttpResponseCode.RequestedRangeNotSatisfiable, "Request Range Not satisfiable"),
        HttpStatusPhrase(HttpResponseCode.ExpectationFailed,            "Expectation Failed"),
        HttpStatusPhrase(HttpResponseCode.InternalServerError,          "Internal server Error"),
        HttpStatusPhrase(HttpResponseCode.NotImplemented,               "Not Implemented"),
        HttpStatusPhrase(HttpResponseCode.BadGateway,                   "Bad Gateway"),
        HttpStatusPhrase(HttpResponseCode.ServiceUnavailable,           "Service Unavailable"),
        HttpStatusPhrase(HttpResponseCode.GatewayTimeout,               "Gateway Timeout"),
        HttpStatusPhrase(HttpResponseCode.VersionNotSupported,          "version Not supported")
    ];

    /**************************************************************************

        HTTP status phrases by status code

     **************************************************************************/

    private static char[][HttpResponseCode] reason_phrases;

    /**************************************************************************

        Obtains the HTTP status phrase for status_code

        Params:
            status_code = HTTP status code

        Returns:
            HTTP status phrase for status_code

        Throws:
            behaves like indexing an associative array

     **************************************************************************/

    static char[] opIndex ( HttpResponseCode status_code )
    {
        return this.reason_phrases[status_code];
    }

    /**************************************************************************

        Static constructor; populates reason_phrases

     **************************************************************************/

    static this ( )
    {
        foreach (srp; this.StatusReasonPhrases)
        {
            this.reason_phrases[srp.status_code] = srp.reason_phrase;
        }

        this.reason_phrases.rehash;
    }
}