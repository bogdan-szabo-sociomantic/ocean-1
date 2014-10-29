/*******************************************************************************

    I/O Exception class which reads, stores and resets the thread-local errno.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        July 2010: Initial release

    authors:        David Eckardt

*******************************************************************************/

module ocean.core.ErrnoIOException;



/*******************************************************************************

    Imports

*******************************************************************************/

import tango.core.Exception : IOException;

import tango.stdc.errno : errno;

import tango.stdc.string : strlen;

import ocean.core.Array : concat, append, toArray;

/*******************************************************************************

    IOException class; base class for IOWarning and IOError

*******************************************************************************/

public class ErrnoIOException : IOException
{
    /**************************************************************************

        Error number

     **************************************************************************/

    int errnum = 0;

    /**************************************************************************

        Constructor

     **************************************************************************/

    this ( ) {super("");}

    public void assertEx ( bool ok, char[] msg, char[] file = "", long line = 0 )
    {
        if (!ok) throw this.opCall(msg, file, line);
    }

    /**************************************************************************

        Queries and resets errno and sets the exception parameters.

        Params:
            file = source code file name
            line = source code line

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( char[] file = "", long line = 0 )
    {
        char[][] msg = null;

        return this.opCall(msg, file, line);
    }

    /**************************************************************************

        Queries and resets errno and sets the exception parameters.

        Params:
            msg  = message
            file = source code file name
            line = source code line

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( char[] msg, char[] file = "", long line = 0 )
    {
        return this.opCall(toArray(msg), file, line);
    }

    /**************************************************************************

        Queries and resets errno and sets the exception parameters.

        Params:
            msg  = list of message strings to concatenate
            file = source code file name
            line = source code line

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( char[][] msg, char[] file = "", long line = 0 )
    {
        scope (exit) .errno = 0;

        return this.opCall(.errno, msg, file, line);
    }

    /**************************************************************************

        Sets the exception parameters.

        Params:
            errnum = error number
            msg    = message
            file   = source code file name
            line   = source code line

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( int errnum, char[] file = "", long line = 0 )
    {
        char[][] msg = null;

        return this.opCall(errnum, msg, file, line);
    }

    /**************************************************************************

        Sets the exception parameters.

        Params:
            errnum = error number
            msg    = message
            file   = source code file name
            line   = source code line

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( int errnum, char[] msg, char[] file = "", long line = 0 )
    {
        return this.opCall(errnum, toArray(msg), file, line);
    }

    /**************************************************************************

        Sets the exception parameters.

        Params:
            errnum = error number
            msg    = list of message strings to concatenate
            file   = source code file name
            line   = source code line

        Returns:
            this instance

     **************************************************************************/

    public typeof (this) opCall ( int errnum, char[][] msg, char[] file = "", long line = 0 )
    {
        this.errnum = errnum;

        super.msg.concat(msg);

        if (this.errnum)
        {
            char[256] buf;
            char* e = strerror_r(errnum, buf.ptr, buf.length);

            if (super.msg.length)
            {
                super.msg.append(" - ");
            }

            super.msg.append(e[0 .. strlen(e)]);
        }

        super.file = file;
        super.line = line;

        return this;
    }

    /**************************************************************************

        Obtains the system error message for errnum.

        The system error message buffer may or may not be copied to buffer, do
        not change characters in the returned string. The message length may be
        truncated to buffer.length - 1.

        Params:
            buffer = string buffer, may or may not be populated
            errnum = error code

        Returns:
            the system error message for errnum.

     **************************************************************************/

    public static char[] strerror ( char[] buffer, int errnum )
    {
        char* e = strerror_r(errnum, buffer.ptr, buffer.length);

        return e? e[0 .. strlen(e)] : null;
    }

    /**************************************************************************

        Called immediately when this instance is deleted.
        (Must be protected to prevent an invariant from failing.)

     **************************************************************************/

    protected override void dispose ( )
    {
        delete super.msg;
    }
}

/******************************************************************************

    Obtains the system error message corresponding to errnum (reentrant/
    thread-safe version of strerror()).

    Note: This is the GNU (not the POSIX) version of strerror_r().

    @see http://www.kernel.org/doc/man-pages/online/pages/man3/strerror.3.html

    "The GNU-specific strerror_r() returns a pointer to a string containing the
     error message.  This may be either a pointer to a string that the function
     stores in buf, or a pointer to some (immutable) static string (in which case
     buf is unused).  If the function stores a string in buf, then at most buflen
     bytes are stored (the string may be truncated if buflen is too small) and
     the string always includes a terminating null byte."

    Tries have shown that buffer may actually not be populated.

    Params:
        errnum = error number
        buffer = error message destination buffer (may or may not be populated)
        buflen = destination buffer length

    Returns:
        a NUL-terminated string containing the error message

******************************************************************************/

private extern (C) char* strerror_r ( int errnum, char* buffer, size_t buflen );

