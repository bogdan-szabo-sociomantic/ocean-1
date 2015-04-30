/*******************************************************************************

    copyright:      Copyright (c) 2013 sociomantic labs. All rights reserved

    version:        June 2013: Initial release

    authors:        Hatem Oraby, Leandro Lucarella

    A D wrapper around the GNU readline/readline file

    readline is a powerful library for reading the user input from the console.

    For example if an application frequently asks for user-input during its
    operation then using readline provides the following benefits:
       - User can browse previous submitted lines using up/down arrows.
       - Terminal shortcuts (e.g ctrl+r, ctrl+w, ctrl+y) are enabled by default.
       - Providing text auto-completion, by default it is enabled to complete
         files and directories for the path that the application was run from.
       - Make the application use the customized configuration that the user
         defined for readline on his machine.

    There are much more functionalities that the readline library provides.
    Please refer to the documentation for the more information:
        - http://cnswww.cns.cwru.edu/php/chet/readline/rltop.html

    Notes:
        Requires linking with libreadline

*******************************************************************************/

module ocean.io.console.readline.Readline;

/*******************************************************************************

    Imports

*******************************************************************************/

import C = ocean.io.console.readline.c.readline;
import ocean.core.Array : copy;
import ocean.text.util.StringC;

import tango.stdc.string: strlen;
import tango.stdc.stdlib : free;

/*******************************************************************************

    Reads a line from the terminal and return it, using prompt as a prompt.
    If prompt is NULL or the empty string, no prompt is issued.
    The line returned has the final newline removed, so only the text of the
    line remains.

    Except for the note below, the documentation is taken from the manpage of
    readline. Refer to the readline manpage for more extensive documentation.

    Note:
        If prompt isn't null-terminated and isn't null then it's converted to a
        C null-terminated string before passing it to the C readline function.
        Converting to C string might re-allocate the buffer. If you have tight
        memory constraints, it is highly recommended to provide a null
        terminated string or make sure that the GC block your buffer is stored
        in has a spare byte at the end.

    Params:
        prompt = the string to be prompted to the user (see note above)
        buffer = optional buffer to store the user input, if the buffer is null
        then it would be allocated only if the user provided an input.

    Returns:
        Returns the text of the line read. A blank line returns empty string.
        If EOF is encountered while reading a line, and the line is empty, null
        is returned.  If an EOF  is  read  with  a non-empty line, it is treated
        as a newline.

*******************************************************************************/

char[] readline(char[] prompt = null, char[] buffer = null)
{
    char* prompt_ptr = null;
    if (prompt != null)
    {
        prompt_ptr = StringC.toCstring( prompt );
    }

    char* c_buf = C.readline(prompt_ptr);
    scope (exit) free(c_buf);
    if (c_buf is null)
    {
        return null;
    }

    auto c_buf_len = strlen(c_buf);
    if (buffer is null && c_buf_len == 0)
    {
        buffer.length = 1; //Allocate the pointer so we wouldn't return null
    }
    buffer.copy( c_buf[0..c_buf_len] );
    return buffer;
}

/*******************************************************************************

    Function signature for functions used with the rl_bind_key functions and
    various other functions.

*******************************************************************************/

alias C.rl_command_func_t CommandFunc;

/*******************************************************************************

    Bind a keyboard key to a function.

    The function will be called when the user is prompted for input and he
    presses the bound key.

    Note that by default the tab key is bound to auto-complete the file names
    that exist in the directory the application was run from. To disable this
    bind the tab key with the abort function defined in this module:
        bindKey('\t', abort);

    Params:
        key = ASCII int value of the key to be bound
        func = the func triggered when they key is pressed

*******************************************************************************/

void bindKey(char key, CommandFunc* func)
{
    C.rl_bind_key(cast(int)key, func);
}


/*******************************************************************************

    Completion functions to be used with key bindings

*******************************************************************************/

alias C.rl_abort abort; // Binds a key do nothing (even not write itself)
alias C.rl_insert insert; // Binds a key to just write itself
