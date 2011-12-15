/*******************************************************************************

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        May 2011: Initial release

    authors:        Gavin Norman

    Layout class (wrapping tango.text.convert.Layout) with a single static
    method to write a formatted string into a provided buffer.

    Note: This module exists because a method with this behaviour does not exist
    in tango's Layout -- the closest being the sprint() method, which writes to
    an output buffer, but which will not exceed the passed buffer's length.

    Usage exmaple:

    ---

        import ocean.text.convert.Layout;

        char[] str;

        Layout!(char).print(str, "{}, {}{}", "Hello", "World", '!');

        // str will now hold the string "Hello, World!"

    ---

*******************************************************************************/

module ocean.text.convert.Layout;



/*******************************************************************************

    Imports

*******************************************************************************/

private import ocean.core.Array : append;

private import ocean.core.AppendBuffer;

private import TangoLayout = tango.text.convert.Layout;


/*******************************************************************************

 Platform issues ...

*******************************************************************************/

version (GNU)
{
    private import tango.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;
}
else version (LDC)
{
    private import tango.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;
}
else version (DigitalMars)
{
    private import tango.core.Vararg;

    alias void* Arg;
    alias va_list ArgList;

    version (X86_64) version = DigitalMarsX64;
}
else
{
    alias void* Arg;
    alias void* ArgList;
}


class Layout ( T )
{
    /***************************************************************************

        Global instance because Layout.instance() is not thread-safe.
    
    ***************************************************************************/

    private static TangoLayout.Layout!(T) layout;
    
    static this ( )
    {
        this.layout = new TangoLayout.Layout!(T);
    }
    
    /***************************************************************************

        Outputs a formatted string into the provided buffer.

        Note that the formatted string is appended into the buffer, it will not
        overwrite any existing content.

        Params:
            output = output buffer, length will be increased to accommadate
                formatted string
            formatStr = format string
            ... = format string parameters

        Returns:
            resulting string (output)

    ***************************************************************************/

    static public char[] print ( ref char[] output, T[] formatStr, ... )
    {
        uint layoutSink ( char[] s )
        {
            output.append(s);
            return s.length;
        }
        
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            this.layout.convert(&layoutSink, _arguments, ap, formatStr);
        }
        else
            this.layout.convert(&layoutSink, _arguments, _argptr, formatStr);
        
        return output;
    }
}

/*******************************************************************************

    AppendBuffer using Layout

*******************************************************************************/

class StringLayout ( T = char ) : AppendBuffer!(T)
{
    /***************************************************************************

        Layout instance
    
    ***************************************************************************/

    private TangoLayout.Layout!(T) layout;
    
    /***************************************************************************

        Constructor
    
    ***************************************************************************/

    this ( )
    {
        this.layout = new TangoLayout.Layout!(T);
    }
    
    /***************************************************************************

        Constructor
        
        Params:
            n = initial buffer length
    
    ***************************************************************************/

    this ( size_t n )
    {
        super(n);
        this.layout = new TangoLayout.Layout!(T);
    }
    
    /**************************************************************************
    
        Appends all given variable arguments in the order of appearance,
        formatted using the default format for each argument. 
        
        Params:
            ... = values to format
            
        Returns:
            this instance
    
     **************************************************************************/

    typeof (this) opCall ( ... )
    {
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            return this.vwrite(_arguments, ap);
        }
        else
            return this.vwrite(_arguments, _argptr);
    }
    
    /**************************************************************************
    
        Appends the variable arguments to the content, formatted according to
        fmt, if any. If no variable arguments are given, simply appends fmt to
        the content. 
        
        Params:
            fmt = format specifier or string to write if no variable arguments
                  are given.
            ... = values to format or nothing to simply append fmt.
            
        Returns:
            this instance
    
     **************************************************************************/

    T[] format ( T[] fmt, ... )
    {
        version (DigitalMarsX64)
        {
            va_list ap;

            va_start(ap, __va_argsave);

            scope(exit) va_end(ap);

            return this.vformat(fmt, _arguments, ap);
        }
        else
            return this.vformat(fmt, _arguments, _argptr);
    }
    
    /**************************************************************************
    
        Appends the variable arguments to the content, formatted according to
        fmt, if any. If no variable arguments are given, simply appends fmt to
        the content.
        
        Params:
            fmt       = format specifier or string to write if arguments is
                        empty
            arguments = type ids of arguments which argptr points to
            argptr    = pointer to variable argument data
            
        Returns:
            this instance
    
     **************************************************************************/

    T[] vformat ( T[] fmt, TypeInfo[] arguments, va_list argptr )
    {
        if (arguments.length)
        {
            this.layout.convert((char[] chunk){return cast(uint)super.append(chunk).length;}, arguments, argptr, fmt);
        }
        else
        {
            super.append(fmt);
        }
        
        return super[];
    }
    
    /**************************************************************************
    
        Formats all given variable arguments in the order of appearance, using
        the default format for each argument. 
        
        Params:
            arguments = type ids of arguments which argptr points to
            argptr    = pointer to variable argument data
            
        Returns:
            this instance
    
     **************************************************************************/
    
    typeof (this) vwrite ( TypeInfo[] arguments, va_list argptr )
    {
        foreach (ref argument; arguments)
        {
            if (argument is typeid (T[]))
            {
                super ~= va_arg!(T[])(argptr);
            }
            else if (argument is typeid (T))
            {
                super ~= va_arg!(T)(argptr);
            }
            else
            {
                this.vformat("{}", (&argument)[0 .. 1], argptr);
            }
        }
        
        return this;
    }
}

/******************************************************************************/

unittest
{
    char[] str;
    
    assert (Layout!(char).print(str, "{}, {}{}", "Hello", "World", '!') == "Hello, World!");
    assert (str == "Hello, World!");
}
