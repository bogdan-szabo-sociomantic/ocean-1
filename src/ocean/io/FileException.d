/**************************************************************************

    Extension to ErrnoException specific to file I/O errors

    Copyright: Copyright (c) 2015 sociomantic labs. All rights reserved

**************************************************************************/

module ocean.io.FileException;

/**************************************************************************

    Imports

**************************************************************************/

import ocean.sys.ErrnoException;
import ocean.stdc.errno;

/**************************************************************************

    Exception class that checks error status on both file descriptor
    and via global errno

**************************************************************************/

class FileException : ErrnoException
{
    import ocean.stdc.stdio: FILE, ferror, feof, clearerr;

    /// Make ErrnoException's enforce available
    public alias ErrnoException.enforce enforce;

    /**************************************************************************

        Enforces success of file I/O operation

        Params:
            ok = I/O expression that returns `false` on failure
            filename =  filename that was used for the I/O (only used in
                message formatting)
            handle = file handle that was used for the I/O (can be null)

        Throws:
            `this` upon any of conditions:
                - !ok
                - handle has error status
                - handle has EOF status
                - errno != 0

    **************************************************************************/

    public void enforce ( bool ok, cstring filename, FILE* handle,
        istring file = __FILE__, int line = __LINE__ )
    {
        int err_num = handle ? ferror(handle) : .errno;

        if (err_num)
        {
            if (handle)
                clearerr(handle);

            if (ok)
            {
                throw this.set(err_num, "", file, line)
                    .append(" (operation on '")
                    .append(filename)
                    .append("' returned success status, but errno is non-zero)");
            }
            else
            {
                throw this.set(err_num, "", file, line)
                    .append(" (failed operation on '")
                    .append(filename)
                    .append("')");
            }
        }

        if (handle !is null && !ok)
        {
            if (feof(handle) != 0)
            {
                // not really an errno
                throw this.ReusableImpl
                    .set("Reading past end of file", file, line)
                    .append(" (failed operation on '")
                    .append(filename)
                    .append("')");
            }
        }
    }
}

version (UnitTest)
{
    import ocean.stdc.posix.stdio;
    import ocean.core.Test;
}

///
unittest
{
    auto e = new FileException;
    auto f = fdopen(42, "r".ptr);

    try
    {
        e.enforce(f !is null, "<42>", f);
        assert (false);
    }
    catch (FileException e)
    {
        test!("==")(
            e.toString(),
            "Bad file descriptor (failed operation on '<42>')"[]
        );
        test!("==")(e.line, __LINE__ - 9);
    }
}
