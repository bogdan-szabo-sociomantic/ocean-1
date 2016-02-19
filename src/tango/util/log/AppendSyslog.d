/*******************************************************************************

 copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

 license:        BSD style: $(LICENSE)

 version:        Initial release: May 2004

 author:         Kris & Marenz

 *******************************************************************************/

module tango.util.log.AppendSyslog;

import tango.transition;

import tango.time.Time;

import Path = tango.io.Path, tango.io.device.File, tango.io.FilePath;

import tango.io.model.IFile;

import tango.util.log.Log, tango.util.log.AppendFile;

import Integer = tango.text.convert.Integer;

import tango.text.convert.Format;

import tango.math.Math : max;

import tango.sys.Process;

import tango.io.Stdout;

/*******************************************************************************

     Append log messages to a file set

*******************************************************************************/

public class AppendSyslog: Filer
{
    private Mask mask_;
    private long max_size, file_size, max_files, compress_index;

    private FilePath file_path;
    private istring path;
    private istring compress_suffix;
    private Process compress_cmd;

    /***********************************************************************

     Create an AppendSyslog upon a file-set with the specified
     path and optional layout. The minimal file count is two
     and the maximum is 1000 (explicitly 999).
     The minimal compress_begin index is 2.


        Params:
            path            = path to the first logfile
            count           = maximum number of logfiles
            max_size        = maximum size of a logfile in bytes
            compress_cmd    = command to use to compress logfiles
            compress_suffix = suffix for compressed logfiles
            compress_begin  = index after which logfiles should be compressed
            how             = which layout to use

     ***********************************************************************/

    this ( istring path, uint count, long max_size,
           istring compress_cmd = null, istring compress_suffix = null,
           size_t compress_begin = 2, Appender.Layout how = null )
    {
        Stdout.formatln("Warning: AppendSyslog is going to be deprecated in "
            ~ "the next ocean release. This will mean that there is no longer "
            ~ "any automatc log rotation support in ocean. Applications which "
            ~ "require log rotation should move across to using the system "
            ~ "logrotate facility. Most programs which use loggers should be "
            ~ "based on ocean's `DaemonApp`, which provides all the facilities "
            ~ "required for rotated log files (see the v1.26.0 release notes: "
            ~ "(https://github.com/sociomantic/ocean/releases/tag/v1.26.0) for "
            ~ "migration instructions).");

        assert (path);
        assert (count < 1000);
        assert (compress_begin >= 2);

        // Get a unique fingerprint for this instance
        mask_ = register(path);

        File.Style style = File.WriteAppending;
        style.share = File.Share.Read;
        auto conduit = new File(path, style);

        configure(conduit);

        // remember the maximum size
        this.max_size  = max_size;
        // and the current size
        this.file_size = conduit.length;
        this.max_files = count;

        // set provided layout (ignored when null)
        layout(how);

        this.file_path = new FilePath(path);
        this.file_path.pop();

        this.path = path.dup;
        // "gzip {}"   this.path.{}

        char[512] buf, buf1;

        auto compr_path = Format.sprint(buf, "{}.{}", this.path, compress_begin);

        auto cmd = Format.sprint(buf1, compress_cmd, compr_path);

        this.compress_cmd    = new Process(cmd.dup);
        this.compress_suffix = "." ~ compress_suffix;
        this.compress_index  = compress_begin;
    }

    /***********************************************************************

     Return the fingerprint for this class

     ***********************************************************************/

    final override Mask mask ( )
    {
        return mask_;
    }

    /***********************************************************************

     Return the name of this class

     ***********************************************************************/

    final override istring name ( )
    {
        return this.classinfo.name;
    }

    /***********************************************************************

     Append an event to the output

     ***********************************************************************/

    final override void append ( LogEvent event )
    {
        synchronized (this) 
        {
            // file already full?
            if (file_size >= max_size) nextFile();

            size_t write ( Const!(void)[] content )
            {
                file_size += content.length;
                return buffer.write(content);
            }

            // write log message and flush it
            layout.format(event, &write);
            try
            {
                write(FileConst.NewlineString);
                buffer.flush;
            }
            catch ( Exception e )
            {
                Stderr.formatln("Failed to write logline: {}", e.msg);
            }
        }
    }

    private void openConduit ()
    {
        this.file_size = 0;
        // make it shareable for read
        File.Style style = File.WriteAppending;
        style.share = File.Share.Read;
        (cast(File) this.conduit).open(this.path, style);
        //this.buffer.output(this.conduit);
    }

    /***********************************************************************

        Switch to the next file within the set

     ***********************************************************************/

    private void nextFile ( )
    {
        size_t free, used;

        size_t oldest = 1;
        char[512] buf;

        buf[0 .. this.path.length] = this.path;
        buf[this.path.length]  = '.';

        // release currently opened file
        this.conduit.detach();

        foreach ( ref file; this.file_path )
        {
            auto pathlen = file.path.length;

            if ( file.name.length > this.path.length + 1 - pathlen &&
                 file.name[0 .. this.path.length - pathlen] == this.path[pathlen .. $] )
            {
                uint ate = 0;
                auto num = Integer.parse(file.name[this.path.length - pathlen + 1 .. $], 0, &ate);

                if ( ate != 0 )
                {
                    oldest = max(oldest, num);
                }
            }
        }

        for ( auto i = oldest; i > 0; --i )
        {
            auto compress = i >= this.compress_index ?
                            this.compress_suffix : "";

            auto path = Format.sprint(buf, "{}.{}{}", this.path, i,
                                      compress);

            this.file_path.set(path, true);

            if ( this.file_path.exists() )
            {
                if ( i + 1 < this.max_files)
                {
                    path = Format.sprint(buf, "{}.{}{}\0", this.path, i+1,
                                         compress);

                    this.file_path.rename(path);

                    if ( i + 1 == this.compress_index ) with (this.compress_cmd)
                    {
                        if ( isRunning )
                        {
                            wait();
                            close();
                        }

                        execute();
                    }
                }
                else this.file_path.remove();
            }
        }

        this.file_path.set(this.path);

        if ( this.file_path.exists() )
        {
            auto path = Format.sprint(buf, "{}.{}\0", this.path, 1);

            this.file_path.rename(path);
        }

        this.openConduit ();

        this.file_path.set(this.path);
        this.file_path.pop();
    }
}

/*******************************************************************************

 *******************************************************************************/

debug (AppendSyslog)
{
    void main ( )
    {
        Log.root.add(new AppendFiles("foo", 5, 6));
        auto log = Log.lookup("fu.bar");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");
        log.trace("hello {}", "world");

    }
}
