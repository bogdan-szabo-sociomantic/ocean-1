/*******************************************************************************

    Console output

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        November 2011: Initial release

    authors:        Gavin Norman

    Console output classes extending those in tango.io.Stdout.

    Additional features are:
        * clearline() method which erases the rest of the line

*******************************************************************************/

module ocean.io.Stdout;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.io.Terminal;

private import tango.io.device.Conduit;

private import tango.io.stream.Format;

private import tango.io.Console;

private import tango.text.convert.Layout;

version (Posix) private import tango.stdc.posix.unistd : isatty;



/*******************************************************************************

    Static output instances

*******************************************************************************/

public static TerminalOutput!(char) Stdout; /// Global standard output.
public static TerminalOutput!(char) Stderr; /// Global error output.
public alias Stdout stdout; /// Alternative.
public alias Stderr stderr; /// Alternative.

static this ( )
{
    // note that a static-ctor inside Layout fails
    // to be invoked before this is executed (bug)
    auto layout = Layout!(char).instance;

    Stdout = new TerminalOutput!(char)(layout, Cout.stream);
    Stderr = new TerminalOutput!(char)(layout, Cerr.stream);

    Stdout.flush = !Cout.redirected;
    Stdout.redirect = Cout.redirected;
    Stderr.flush = !Cerr.redirected;
    Stderr.redirect = Cerr.redirected;
}



/*******************************************************************************

    Terminal output class.

    Derived from FormatOutput in tango.io.stream.Format, and reimplements
    methods to return typeof(this), for easy method chaining. Note that not all
    methods are reimplemented in this way, only those which we commonly use.
    Others may be added if needed.

*******************************************************************************/

public class TerminalOutput ( T ) : FormatOutput!(T)
{
    /***************************************************************************

        True if it's redirected.

    ***************************************************************************/

    protected bool redirect;


    /***************************************************************************

        Construct a FormatOutput instance, tying the provided stream to a layout
        formatter.

    ***************************************************************************/

    public this (OutputStream output, T[] eol = Eol)
    {
        this (Layout!(T).instance, output, eol);
    }


    /***************************************************************************

        Construct a FormatOutput instance, tying the provided stream to a layout
        formatter.

    ***************************************************************************/

    public this (Layout!(T) convert, OutputStream output, T[] eol = Eol)
    {
        super(convert, output, eol);
    }


    /***************************************************************************

        Layout using the provided formatting specification.

    ***************************************************************************/

    public typeof(this) format ( T[] fmt, ... )
    {
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            super.format(fmt, _arguments, ap);
        }
        else
            super.format(fmt, _arguments, _argptr);

        return this;
    }


    /***************************************************************************

        Layout using the provided formatting specification. Varargs pass-through
        version.

    ***************************************************************************/

    public typeof(this) format (T[] fmt, TypeInfo[] arguments, ArgList args)
    {
        super.format(fmt, arguments, args);
        return this;
    }


    /***************************************************************************

        Layout using the provided formatting specification, and append a
        newline.

    ***************************************************************************/

    public typeof(this) formatln ( T[] fmt, ... )
    {
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            super.formatln(fmt, _arguments, ap);
        }
        else
            super.formatln(fmt, _arguments, _argptr);

        return this;
    }


    /***************************************************************************

        Layout using the provided formatting specification, and append a
        newline. Varargs pass-through version.

    ***************************************************************************/

    public typeof(this) formatln (T[] fmt, TypeInfo[] arguments, ArgList args)
    {
        super.formatln(fmt, arguments, args);
        return this;
    }


    /***************************************************************************

        Output a newline and optionally flush.

    ***************************************************************************/

    public typeof(this) newline ( )
    {
        super.newline;
        return this;
    }


    /***************************************************************************

        Emit/purge buffered content.

    ***************************************************************************/

    public typeof(this) flush ( )
    {
        super.flush;
        return this;
    }


    /***************************************************************************

        Control implicit flushing of newline(), where true enables flushing. An
        explicit flush() will always flush the output.

    ***************************************************************************/

    public typeof(this) flush ( bool yes )
    {
        super.flush(yes);
        return this;
    }


    /***************************************************************************

        Output terminal control characters to clear the rest of the line. Note:
        does not flush. (Flush explicitly if you need to.)

    ***************************************************************************/

    public typeof(this) clearline ( )
    {
        if (this.redirect)
        {
            return this.newline;
        }
        this.sink.write(Terminal.CSI);
        this.sink.write(Terminal.ERASE_REST_OF_LINE);
        return this;
    }
}

