/*******************************************************************************

    Functions to convert non-ascii characters to percent encoded form, and vice
    versa.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        September 2011: Initial release

    authors:        Gavin Norman

    Only non-ascii and non-reserved characters are converted. Reserved
    characters are by default:

        !$&'()*+,;=:@/?

    (an alternative list can be passed to the encode() function, if required).

    See:

    ---

        http://en.wikipedia.org/wiki/Percent-encoding

    ---

    Link with:

    ---

        -L-lgblib-2.0

    ---

    Usage example:

    ---

        import PercentEncoding = ocean.text.url.PercentEncoding;

        char[] url = "http://www.stepstone.de/upload_DE/logo/G/logoGebühreneinzugszentrale_8974DE.gif".dup;
        char[] encoded;
        char[] working;

        PercentEncoding.encode(url, encoded, working);

        // 'encoded' now equals:
        // "http://www.stepstone.de/upload_DE/logo/G/logoGeb%C3%BChreneinzugszentrale_8974DE.gif"

    ---

    TODO: at present these functions are wrappers around the equivalent glib
    functions, which have the desired behaviour. (The methods in tango.net.Uri
    do *not* have the desired behaviour -- it ruthlessly encodes every character
    in the string, including ascii & reserved characters!) It may be desirable
    at some point to write a pure D implementation of these functions, so as to:

        1. remove the dependancy on linking with the glib library
        2. avoid the string allocation & free which occurs with each call

*******************************************************************************/

deprecated module ocean.text.url.PercentEncoding;

