/*******************************************************************************

    HTTP Constants that are not defined in tango.net.http.HttpConst 
    
    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved
    
    version:        April 2009: Initial release
    
    authors:        Lars Kirchhoff, Thomas Nicolai
                
*******************************************************************************/
        
module      net.http.HttpConstants;


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



