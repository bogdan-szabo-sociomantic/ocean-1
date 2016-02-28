/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)

        version:        Initial release: May 2004

        author:         Kris

*******************************************************************************/

module ocean.util.log.AppendFiles;

import ocean.transition;

import ocean.time.Time;

import Path = ocean.io.Path,
       ocean.io.device.File;

import ocean.io.model.IFile;

import ocean.util.log.Log,
       ocean.util.log.AppendFile;

/*******************************************************************************

        Append log messages to a file set

*******************************************************************************/

public class AppendFiles : Filer
{
        private Mask            mask_;
        private char[][]        paths;
        private int             index;
        private long            maxSize,
                                fileSize;

        /***********************************************************************

                Create an AppendFiles upon a file-set with the specified
                path and optional layout. The minimal file count is two
                and the maximum is 1000 (explicitly 999). Note that files
                are numbered starting with zero rather than one.

                A path of "my.log" will be expanded to "my.0.log".

                maxSize is the advisory maximum size of a single log-file,
                in bytes.

                Where a file set already exists, we resume appending to
                the one with the most recent activity timestamp

        ***********************************************************************/

        this (char[] path, int count, long maxSize, Appender.Layout how = null)
        {
                --count;
                assert (path);
                assert (count > 0 && count < 1000);

                // split the path into components
                auto c = Path.parse (path);

                // Get a unique fingerprint for this instance
                auto ipath = assumeUnique(path);
                mask_ = register (ipath);

                char[3] x;
                Time mostRecent;
                for (int i=0; i <= count; ++i)
                    {
                    x[0] = cast(char)('0' + i/100);
                    x[1] = cast(char)('0' + i/10%10);
                    x[2] = cast(char)('0' + i%10);
                    auto p = c.toString[0..$-c.suffix.length] ~ x ~ c.suffix;
                    paths ~= p;

                    // use the most recent file in the set
                    if (Path.exists(p))
                       {
                       auto modified = Path.modified(p);
                       if (modified > mostRecent)
                          {
                          mostRecent = modified;
                          index = i;
                          }
                       }
                    }

                // remember the maximum size
                this.maxSize = maxSize;

                // adjust index and open the appropriate log file
                --index;
                File.Style style = File.WriteAppending;
                style.share = File.Share.Read;
                auto conduit = new File(ipath, style);
                configure(conduit);
                fileSize = conduit.length;

                // set provided layout (ignored when null)
                layout (how);
        }

        /***********************************************************************

                Return the fingerprint for this class

        ***********************************************************************/

        final override Mask mask ()
        {
                return mask_;
        }

        /***********************************************************************

                Return the name of this class

        ***********************************************************************/

        final override istring name ()
        {
                return this.classinfo.name;
        }

        /***********************************************************************

                Append an event to the output

        ***********************************************************************/

        final override void append (LogEvent event)
        {
            synchronized (this)
            {
                char[] msg;

                // file already full?
                if (fileSize >= maxSize)
                    nextFile (true);

                size_t write (Const!(void)[] content)
                {
                        fileSize += content.length;
                        return buffer.write (content);
                }

                // write log message and flush it
                layout.format (event, &write);
                write (FileConst.NewlineString);
                buffer.flush;
            }
        }

        /***********************************************************************

                Switch to the next file within the set

        ***********************************************************************/

        private void nextFile (bool reset)
        {
                // select next file in the set
                if (++index >= paths.length)
                    index = 0;

                // close any existing conduit
                this.conduit.detach();

                // make it shareable for read
                File.Style style = File.WriteAppending;
                style.share = File.Share.Read;
                File conduit = cast(File) this.conduit;
                conduit.open(paths[index], style);

                // reset file size
                if (reset)
                    conduit.truncate (fileSize = 0);
                else
                   fileSize = conduit.length;
        }
}

/*******************************************************************************

*******************************************************************************/

debug (AppendFiles)
{
        void main()
        {
                Log.root.add (new AppendFiles ("foo", 5, 6));
                auto log = Log.lookup ("fu.bar");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");
                log.trace ("hello {}", "world");

        }
}
