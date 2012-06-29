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

private import ocean.util.container.AppendBuffer;

private import TangoLayout = tango.text.convert.Layout;


/*******************************************************************************

 Platform issues ...

*******************************************************************************/

version (DigitalMars) version (X86_64)
{
    version = DigitalMarsX86_64;
}

version (DigitalMarsX86_64)
{
    /*
     * va_list/_start/_arg/_end must be public imported because they are used in
     * the vaArg template, which is instantiated in other modules as well.
     */
    
    public import tango.core.Vararg: va_list, va_start, va_arg, va_end,
                               // implicitly referenced by the compiler... YEAH!
                                     __va_argsave_t;
}
else
{
    private import tango.core.Vararg: va_list, va_arg;
}

/*******************************************************************************

    

*******************************************************************************/

abstract class Layout ( T = char )
{
    /**************************************************************************
    
        Layout formatter instance
    
     **************************************************************************/
    
    private const TangoLayout.Layout!(T) layout;
    
    /**************************************************************************
    
        Constructor
    
     **************************************************************************/
    
    protected this ( )
    {
        this.layout = new TangoLayout.Layout!(T);
    }
    
    /**************************************************************************
    
        Disposer
    
     **************************************************************************/
    
    protected override void dispose ( )
    {
        delete this.layout;
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

    static public T[] print ( ref T[] output, T[] formatStr, ... )
    {
        uint layoutSink ( T[] s )
        {
            return cast (uint) .append(output, s).length;
        }
        
        mixin vaArgCall!();
        
        vaArgCall((TypeInfo[] arguments, va_list argptr)
        {
            TangoLayout.Layout!(T).instance.convert(&layoutSink, arguments, argptr, formatStr);
        });
        
        return output;
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

    public typeof (this) format ( T[] fmt, ... )
    {
        mixin vaArgCall!(typeof (this), T[]);
        
        return vaArgCall(&this.vformat, fmt);
    }
    
    /**************************************************************************
    
        Appends all given variable arguments in the order of appearance,
        formatted using the default format for each argument. 
        
        Params:
            ... = values to format
            
        Returns:
            this instance
    
     **************************************************************************/

    public typeof (this) opCall ( ... )
    {
        mixin vaArgCall!(typeof (this));
        
        return vaArgCall(&this.vwrite);
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

    public typeof (this) vformat ( T[] fmt, TypeInfo[] arguments, va_list argptr )
    {
        if (arguments.length)
        {
            this.layout.convert(&this.append, arguments, argptr, fmt);
        }
        else
        {
            this.append(fmt);
        }
        
        return this;
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
    
    public typeof (this) vwrite ( TypeInfo[] arguments, va_list argptr )
    {
        foreach (ref argument; arguments)
        {
            /**************************************************************
            
                Shifts argptr to the next argument. 
                
                Returns:
                    argptr before shifting
                
             **************************************************************/
            
            version (X86) void* va_arg_ptr ( )
            {
                const size_t n = size_t.sizeof - 1;
                
                scope (exit) argptr += ((argument.tsize + n) & ~n);
                
                return argptr;
            }
            
            if (argument is typeid (T[]))
            {
                 this.append(va_arg!(T[])(argptr));
            }
            else if (argument is typeid (T))
            {
                version (X86)
                {
                    T* xp = cast (T*) va_arg_ptr;
                }
                else
                {
                    T x   = va_arg!(T)(argptr);
                    T* xp = &x;
                }
                
                this.append(xp[0 .. 1]);
            }
            else
            {
                /**************************************************************
                
                    For x86 (not x86-64) va_list is void*, argptr points to the
                    current argument and must be shifted to the next one. Since
                    argptr is forwarded to vformat as value, we need to shift it
                    here.
                    
                    For x86-64 va_list is a reference to an object which is
                    shifted automatically by va_arg(), indirectly called from
                    this.vformat(), so we do not need to care about it. 
                
                 **************************************************************/
                
                version (X86)
                {
                    void* xp = va_arg_ptr;
                }
                else
                {
                    void* xp = argptr;
                }
                
                this.vformat("{}", (&argument)[0 .. 1], xp);
            }
        }
        
        return this;
    }
    
    /**************************************************************************
    
        Output appender, called repeatedly when there is string data to append.
        
        Params:
            chunk = string data to append or write
            
         Returns:
             number of elements appended/written
    
     **************************************************************************/
    
    abstract protected uint append ( T[] chunk );
}

/*******************************************************************************

    AppendBuffer using Layout

*******************************************************************************/

class StringLayout ( T = char ) : AppendBuffer!(T)
{
    /***************************************************************************

        Buffer appending layout formatter
    
    ***************************************************************************/
    
    class AppendLayout : Layout!(T)
    {
        protected uint append ( T[] chunk )
        {
            return cast (uint) this.outer.append(chunk).length;
        }
    }
    
    private const Layout!(T) layout;
    
    /***************************************************************************

        Constructor
        
        Params:
            n = initial buffer length
    
    ***************************************************************************/

    public this ( size_t n = 0 )
    {
        super(n);
        
        this.layout = this.new AppendLayout;
    }
    
    /***************************************************************************

        Disposer
    
    ***************************************************************************/
    
    protected override void dispose ( )
    {
        super.dispose();
        delete this.layout;
    }
    
    /**************************************************************************
    
        Appends all given variable arguments in the order of appearance,
        formatted using the default format for each argument. 
        
        Params:
            ... = values to format
            
        Returns:
            this instance
    
     **************************************************************************/

    T[] opCall ( ... )
    {
        mixin vaArgCall!(T[]);
        
        return vaArgCall(&this.vwrite);
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
        mixin vaArgCall!(T[], T[]);
        
        return vaArgCall(&this.vformat, fmt);
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
        this.layout.vformat(fmt, arguments, argptr);
            
        return this[];
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
    
    T[] vwrite ( TypeInfo[] arguments, va_list argptr )
    {
        this.layout.vwrite(arguments, argptr);
        
        return this[];
    }
}

/*******************************************************************************

    To be mixed into a variadic method.

    Calls dg with _arguments and _argptr, calling va_start()/va_end() if
    required for the current platform and compiler. dg must use va_arg() from
    tango.core.Vararg to iterate over argptr. 
    
    dg must comply to
    
        R delegate ( A dg_args, TypeInfo[] arguments, va_list argptr )
        
    where R is the return type and dg_args
    
    Basic usage:
    ---
    
        void f ( ... )
        {
            mixin vaArgCall!();
            
            vaArgCall(
                (TypeInfo[] arguments, va_list argptr)
                {
                    // use va_args(argptr) to access the arguments 
                }
            );
        }
    
    ---
    
    Template params:
        R = dg return type
        A = types of additional arguments for dg
    
    Params:
        dg      = callback delegate
        dg_args = additional arguments for dg
    
    Returns:
        passes through the return value of dg.
    
*******************************************************************************/

public R vaArgCall ( R = void, A ... ) ( R delegate ( A dg_args, TypeInfo[] arguments, va_list argptr ) dg,
                                         A dg_args )
{
    version (DigitalMarsX86_64)
    {
        va_list ap;

        va_start(ap, __va_argsave);

        scope(exit) va_end(ap);
        
        return dg(dg_args, _arguments, ap);
    }
    else
    {
        return dg(dg_args, _arguments, _argptr);
    }
}

/******************************************************************************/

unittest
{
    char[] str;
    
    assert (Layout!(char).print(str, "{}, {}{}", "Hello", "World", '!') == "Hello, World!");
    assert (str == "Hello, World!");
}
