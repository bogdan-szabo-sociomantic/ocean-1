/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        July 2011: Initial release

    authors:        Gavin Norman

    File device, derived from tango.io.device.File and providing a callback
    which is invoked whenever data is transmitted (read or written). The
    callback notifies the user how many bytes were transmitted, as well as the
    total number of bytes transmitted since the file was opened.

    Usage example:

    ---

        import ocean.io.device.ProgressFile;
        import tango.io.Stdout;

        // Delegate called when data is read/written
        void progress ( size_t bytes, ulong total_bytes )
        {
            Stdout.formatln("{} bytes written, {} in total", bytes, total_bytes);
        }

        auto file = new ProgressFile("test.tmp", &progress, ProgressFile.WriteCreate);

        file.write("hello");

    ---

*******************************************************************************/

module ocean.io.device.ProgressFile;



/*******************************************************************************

    Imports

*******************************************************************************/

private import tango.io.device.File;



class ProgressFile : File
{
    /***************************************************************************

        Delegate to report progress of file transmission.

    ***************************************************************************/

    public alias void delegate ( size_t bytes, ulong total_bytes ) ProgressDg;

    private ProgressDg progress_dg;


    /***************************************************************************

        Internal count of total bytes transmitted. Reset to 0 when open() is
        called.

    ***************************************************************************/

    private ulong total_bytes;


    /***************************************************************************

        Aliases for the various file access styles, to avoid needing to import
        File as well.

    ***************************************************************************/

    public alias File.ReadExisting ReadExisting;
    public alias File.ReadShared ReadShared;
    public alias File.WriteExisting WriteExisting;
    public alias File.WriteCreate WriteCreate;
    public alias File.WriteAppending WriteAppending;
    public alias File.ReadWriteExisting ReadWriteExisting;
    public alias File.ReadWriteCreate ReadWriteCreate;
    public alias File.ReadWriteOpen ReadWriteOpen;


    /***************************************************************************

        Create a File with the provided path and style.

        Note that File is unbuffered by default - wrap an instance
        within tango.io.stream.Buffered for buffered I/O.

        Params:
            progress_dg = delegate to notify of progress
            path = file path
            style = access style of file

    ***************************************************************************/

    public this ( ProgressDg progress_dg, char[] path, Style style = ReadExisting )
    in
    {
        assert(progress_dg !is null, typeof(this).stringof ~ ": progress delegate is null, what's the point?");
    }
    body
    {
        this.progress_dg = progress_dg;
        super.open(path, style);
    }


    /***************************************************************************

        Create a File with the provided path and style. Resets the internal
        bytes counter.

        Params:
            path = file path
            style = access style of file

    ***************************************************************************/

    override public void open ( char[] path, Style style = ReadExisting )
    {
        this.total_bytes = 0;
        super.open(path, style);
    }


    /***************************************************************************

        Reads bytes from the file, notifies the process delegate how many bytes
        were received.

        Params:
            dst = buffer to read into

    ***************************************************************************/

    override public size_t read ( void[] dst )
    {
        auto bytes = super.read(dst);

        this.total_bytes += bytes;

        this.progress_dg(bytes, this.total_bytes);

        return bytes;
    }


    /***************************************************************************

        Writes bytes to the file, notifies the process delegate how many bytes
        were written.

        Params:
            dst = buffer to write into

    ***************************************************************************/

    override public size_t write ( void[] dst )
    {
        auto bytes = super.write(dst);

        this.total_bytes += bytes;

        this.progress_dg(bytes, this.total_bytes);

        return bytes;
    }
}

