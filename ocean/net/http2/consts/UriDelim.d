/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        7/18/2013: Initial release

    authors:        Ben Palmer

    Uri delimiters moved from the old ocean.net.http.HttpConstants module as
    the delimiters were the only constants used in the old module.

*******************************************************************************/

module ocean.net.http2.consts.UriDelim;



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
