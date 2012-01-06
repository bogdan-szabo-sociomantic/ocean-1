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

private import tango.core.Exception : IOException;

private import tango.stdc.errno : errno;

private import tango.stdc.string : strlen;

private import ocean.core.Array : copy, concat, append, toArray;



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
    
    /**************************************************************************
    
        Queries and resets errno and sets the exception parameters.
        
        Params:
            file = source code file name
            line = source code line
        
        Returns:
            this instance
        
     **************************************************************************/
    
    protected void set ( char[] file = "", long line = 0 )
    {
        char[][] msg = null;
        
        this.set(msg, file, line);
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
    
    protected void set ( char[] msg, char[] file = "", long line = 0 )
    {
        this.set(toArray(msg), file, line);
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

    protected void set ( char[][] msg, char[] file = "", long line = 0 )
    {
        scope (exit) .errno = 0;
        
        this.set(.errno, msg, file, line);
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
    
    protected void set ( int errnum, char[] file = "", long line = 0 )
    {
        char[][] msg = null;
        
        this.set(errnum, msg, file, line);
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
    
    protected void set ( int errnum, char[] msg, char[] file = "", long line = 0 )
    {
        this.set(errnum, toArray(msg), file, line);
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

    protected void set ( int errnum, char[][] msg, char[] file = "", long line = 0 )
    {
        this.errnum = errnum;
        
        super.msg.concat(msg);
        
        if (this.errnum)
        {
            char[0x100] buf;
            char* e = strerror_r(errnum, buf.ptr, buf.length);
            
            if (super.msg.length)
            {
                super.msg.append(" - ");
            }
            
            super.msg.append(e[0 .. strlen(e)]);
        }
        
        super.file.copy(file);
        super.line = line;
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

