/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        May 2005: Initial release

        author:         Kris

*******************************************************************************/

module tango.io.device.Device;

import tango.transition;

import  tango.sys.Common;

public  import  tango.io.device.Conduit;

/*******************************************************************************

        Implements a means of reading and writing a file device. Conduits
        are the primary means of accessing external data, and this one is
        used as a superclass for the console, for files, sockets etc.

*******************************************************************************/

class Device : Conduit, ISelectable
{
        /// expose superclass definition also
        public alias Conduit.error error;

        /***********************************************************************

                Throw an IOException noting the last error.

        ***********************************************************************/

        final void error ()
        {
                error (this.toString ~ " :: " ~ SysError.lastMsg);
        }

        /***********************************************************************

                Return the name of this device.

        ***********************************************************************/

        override istring toString ()
        {
                return "<device>";
        }

        /***********************************************************************

                Return a preferred size for buffering conduit I/O.

        ***********************************************************************/

        override size_t bufferSize ()
        {
                return 1024 * 16;
        }

        /***********************************************************************

                 Unix-specific code.

        ***********************************************************************/

        version (Posix)
        {
                protected int handle = -1;

                /***************************************************************

                        Allow adjustment of standard IO handles.

                ***************************************************************/

                protected void reopen (Handle handle)
                {
                        this.handle = handle;
                }

                /***************************************************************

                        Return the underlying OS handle of this Conduit.

                ***************************************************************/

                final Handle fileHandle ()
                {
                        return cast(Handle) handle;
                }

                /***************************************************************

                        Release the underlying file.

                ***************************************************************/

                override void detach ()
                {
                        if (handle >= 0)
                           {
                           //if (scheduler)
                               // TODO Not supported on Posix
                               // scheduler.close (handle, toString);
                           posix.close (handle);
                           }
                        handle = -1;
                }

                /***************************************************************

                        Read a chunk of bytes from the file into the provided
                        array. Returns the number of bytes read, or Eof where
                        there is no further data.

                ***************************************************************/

                override size_t read (void[] dst)
                {
                        auto read = posix.read (handle, dst.ptr, dst.length);

                        if (read is -1)
                            error;
                        else
                           if (read is 0 && dst.length > 0)
                               return Eof;
                        return read;
                }

                /***************************************************************

                        Write a chunk of bytes to the file from the provided
                        array. Returns the number of bytes written, or Eof if
                        the output is no longer available.

                ***************************************************************/

                override size_t write (Const!(void)[] src)
                {
                        auto written = posix.write (handle, src.ptr, src.length);
                        if (written is -1)
                            error;
                        return written;
                }
        }
}