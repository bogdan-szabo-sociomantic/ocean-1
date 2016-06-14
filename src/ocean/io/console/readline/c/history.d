/*******************************************************************************

    Bindings to Readline library's history operations.

    This module contains the D binding of the library functions of history.h.
    Please consult the original header documentation for details.

    You need to have the library installed and link with -lhistory.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.io.console.readline.c.history;

public extern (C)
{
    /***************************************************************************

        Place STRING at the end of the history list.
        The associated data field (if any) is set to NULL.

    ***************************************************************************/

    void add_history(char*);

    /***************************************************************************

        Begin a session in which the history functions might be used. This just
        initializes the interactive variables.

    ***************************************************************************/

    void using_history ();
}
