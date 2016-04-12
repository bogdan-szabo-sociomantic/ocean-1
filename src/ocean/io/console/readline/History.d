/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        June 2013: Initial release

    authors:        Hatem Oraby, Leandro Lucarella

    A D wrapper around the GNU readline/history file

    The module contains functionalities to manipulate the readline session
    history (e.g adding lines to the history so when the user would press the
    up-arrow he would find the old lines).

    Notes:
        - Requires linking with libreadline
        - The user of this module doesn't need to call `using_history()` as its
          automatically called once this module is imported.

*******************************************************************************/

module ocean.io.console.readline.History;

/*******************************************************************************

    Imports

*******************************************************************************/

import C = ocean.io.console.readline.c.history;
import ocean.text.util.StringC;
import ocean.transition;

static this()
{
    // Required by readline to be called before starting the session.
    // From readline documentation for using_history:
    // "Begin a session in which the history functions might be used. This
    // initializes the interactive variables."
    C.using_history();
}

/*******************************************************************************

    Add a line to the history of the readline

    Note:
        If line isn't null-terminated then it's converted to a C null-terminated
        string before passing it to the C add_history function.
        Converting to C string might re-allocate the buffer. If you have tight
        memory constraints, it is highly recommended to provide a null
        terminated string or make sure that the GC block your buffer is stored
        in has a spare byte at the end.

    Params:
        line = the line to add to history

*******************************************************************************/

void addHistory(mstring line)
{
    char* line_ptr = StringC.toCstring( line );
    C.add_history(line_ptr);
}
