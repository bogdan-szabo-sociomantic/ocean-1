module ocean.net.http2.consts.StatusCodes;

private import tango.net.http.HttpConst: HttpHeader, HttpResponseCode;

typedef HttpResponseCode StatusCode = HttpResponseCode.OK;

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
        HttpStatusPhrase(HttpResponseCode.TemporaryRedirect,            "Temporary redirect"),
        HttpStatusPhrase(HttpResponseCode.BadRequest,                   "Bad request"),
        HttpStatusPhrase(HttpResponseCode.Unauthorized,                 "Unauthorized"),
        HttpStatusPhrase(HttpResponseCode.PaymentRequired,              "$$$ Payment required $$$"),
        HttpStatusPhrase(HttpResponseCode.Forbidden,                    "Forbidden"),
        HttpStatusPhrase(HttpResponseCode.NotFound,                     "Not Found"),
        HttpStatusPhrase(HttpResponseCode.MethodNotAllowed,             "Method Not Allowed"),
        HttpStatusPhrase(HttpResponseCode.NotAcceptable,                "Not Acceptable"),
        HttpStatusPhrase(HttpResponseCode.ProxyAuthenticationRequired,  "Proxy Authentication requred"),
        HttpStatusPhrase(HttpResponseCode.RequestTimeout,               "Request Timeout"),
        HttpStatusPhrase(HttpResponseCode.Conflict,                     "Conflict"),
        HttpStatusPhrase(HttpResponseCode.Gone,                         "Gone"),
        HttpStatusPhrase(HttpResponseCode.LengthRequired,               "Length required"),
        HttpStatusPhrase(HttpResponseCode.PreconditionFailed,           "Precondition Failed"),
        HttpStatusPhrase(HttpResponseCode.RequestEntityTooLarge,        "Request Entity Too Large"),
        HttpStatusPhrase(HttpResponseCode.RequestURITooLarge,           "Request Uri Too Large"),
        HttpStatusPhrase(HttpResponseCode.UnsupportedMediaType,         "Unsupported Media Type"),
        HttpStatusPhrase(HttpResponseCode.RequestedRangeNotSatisfiable, "Request range Not satisfiable"),
        HttpStatusPhrase(HttpResponseCode.ExpectationFailed,            "Expectation Failed"),
        HttpStatusPhrase(HttpResponseCode.InternalServerError,          "Internal server Error"),
        HttpStatusPhrase(HttpResponseCode.NotImplemented,               "Not Implemented"),
        HttpStatusPhrase(HttpResponseCode.BadGateway,                   "Bad Gateway"),
        HttpStatusPhrase(HttpResponseCode.ServiceUnavailable,           "Service Unavailable"),
        HttpStatusPhrase(HttpResponseCode.GatewayTimeout,               "Gateway Timeout"),
        HttpStatusPhrase(HttpResponseCode.VersionNotSupported,          "version Not supported")
    ];
    
    private static char[][HttpResponseCode] reason_phrases;
    
    static char[] opIndex ( HttpResponseCode status_code )
    {
        return this.reason_phrases[status_code];
    }
    
    static this ( )
    {
        foreach (srp; this.StatusReasonPhrases)
        {
            this.reason_phrases[srp.status_code] = srp.reason_phrase;
        }
    }
}