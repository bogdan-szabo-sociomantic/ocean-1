/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        7/18/2013: Initial release

    authors:        Ben Palmer

    Uri delimiters moved from the old ocean.net.http.HttpConstants module as
    the delimiters were the only constants used in the old module.

*******************************************************************************/

module ocean.net.http.consts.UriDelim;

/*******************************************************************************

    Imports

*******************************************************************************/

import tango.transition;


/*******************************************************************************

    Uri Delimiter

********************************************************************************/

struct UriDelim
{
    const istring QUERY      = `?`; // seperates uri path & query parameter
    const istring FRAGMENT   = `#`; // seperates uri path & fragment
    const istring QUERY_URL  = `/`; // separates url path elements
    const istring PARAM      = `&`; // seperates key/value pairs
    const istring KEY_VALUE  = `=`; // separate key and value
}
