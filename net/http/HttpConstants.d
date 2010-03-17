/*******************************************************************************

    HTTP Constants that are not defined in tango.net.http.HttpConst 
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    version:        April 2009: Initial release
    
    authors:        Lars Kirchhoff, Thomas Nicolai
                
*******************************************************************************/
        
module      ocean.net.http.HttpConstants;


/*******************************************************************************

    Imports

*******************************************************************************/

import      tango.net.http.HttpConst;


/*******************************************************************************

    Http Request Types

********************************************************************************/


struct HttpRequestType
{       
    static const char[] Options      = "OPTIONS";
    static const char[] Get          = "GET";
    static const char[] Head         = "HEAD";
    static const char[] Post         = "POST";
    static const char[] Put          = "PUT";
    static const char[] Delete       = "DELETE";
    static const char[] Trace        = "TRACE";
    static const char[] Connect      = "CONNECT";   
}


/*******************************************************************************

    Uri Delimiter

********************************************************************************/


struct UriDelim
{       
    static const char[] QUERY      = "?"; // seperates uri path & query parameter
    static const char[] QUERY_URL  = "/"; // separates url path elements
    static const char[] PARAM      = "&"; // seperates key/value pairs
    static const char[] KEY_VALUE  = "="; // separate key and value
}


/*******************************************************************************

    Http Protocol Version

********************************************************************************/


struct HttpProtocolVersion
{       
    static const char[] V_10 = "HTTP/1.0";
    static const char[] V_11 = "HTTP/1.1";   
}


/*******************************************************************************

    Http Header & Query Seperators

********************************************************************************/


const       char[]      HttpHeaderSeparator    = HttpConst.Eol ~ HttpConst.Eol;
const       char[]      HttpQueryLineSeparator = HttpConst.Eol;


/*******************************************************************************

    Http Response Description strings

********************************************************************************/


struct HttpResponseNames
{       
    /**************************************************************************

        Returns a HTTP response code description string.
        
        Params:
            code = HTTP response code
            
        Returns:
            HTTP response code description string

     **************************************************************************/
    
    public static char[] opIndex ( int code )
    {
        char[]* str = code in this.response_names;
        
        return str? *str : "[unknown HTTP response code]";
    }
    
    /**************************************************************************

        Tells whether a description string is available for a HTTP response code.
        
        Params:
            code = HTTP response code
            
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
        foreach (response;
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
            this.response_names[response.code] = response.name;
        }
    }
}



