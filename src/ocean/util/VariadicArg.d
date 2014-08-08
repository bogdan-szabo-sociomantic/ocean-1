/*******************************************************************************

    Utility classes to encapsulate the handling of variadic arguments on
    x86-64 DMD.

    copyright:      Copyright (c) 2009 sociomantic labs. All rights reserved

    version:        August 2012: Initial release

    author:         David Eckardt

    --

    Usage Example:

    ---

    import $(TITLE);

    void myfunc1 ( ... )
    {
        scope valist = new VaList(__va_argsave);

        if (_arguments.length)
        {
            void[] data = valist.next(_arguments[0]);

            // data now contains the argument raw data and _arguments[0] is the
            // run-time information of the argument type.
        }
    }

    void myfunc2 ( ... )
    {
        scope tivalist = new TypeInfoVaList(_arguments, __va_argsave);

        foreach (info, data; tivalist)
        {
            if (info is typeid(int))
            {
                int x = *cast (int*) data.ptr;

                // The current argument is an int and x contains the value.
            }
            else if (info is typeid(char[]))
            {
                char[] str = *cast (char[]*) data.ptr;

                // The current argument is a char[] and str contains the value.
            }

            // Else skip the argument.
        }
    }

    ---

*******************************************************************************/

module ocean.util.VariadicArg;

version (DigitalMars) version (X86_64):

/*******************************************************************************

    Imports.

*******************************************************************************/

public  import tango.stdc.stdarg: __va_argsave_t, __va_list, va_list;

/*******************************************************************************

    Provides sequential access to the elements of a variadic argument list.

*******************************************************************************/

scope class VaList : IVaList
{
    /***************************************************************************

        Constructor

        Params:
            va_argsave = variadic argument list (__va_argsave)

     **************************************************************************/

    public this ( ref __va_argsave_t va_argsave )
    {
        super(va_argsave);
    }

    /***************************************************************************

        Constructor

        Params:
            arglist = variadic argument list (__va_argsave.va)

     **************************************************************************/

    public this ( ref __va_list arglist )
    {
        super(arglist);
    }

    /***************************************************************************

        Constructor

        Params:
            arglist = variadic argument list as obtained from va_start

     **************************************************************************/

    public this ( va_list arglist )
    {
        super(arglist);
    }

    /***************************************************************************

        Pops the next argument from the list and obtains its raw data.

        Params:
            info = typeinfo of the next argument

        Returns:
            a slice of the raw data of the argument popped from the list.

        Out:
            The data length is info.tsize.

     **************************************************************************/

    public void[] next ( TypeInfo info )
    out (data)
    {
        assert (data.length == info.tsize);
    }
    body
    {
        return this.va_arg(info);
    }

    /***************************************************************************

        Pops the next argument from the list and copies its raw data into dst.

        Params:
            info = typeinfo of the next argument
            dst  = destination buffer

        Returns:
            dst

        In:
            dst.length must be info.tsize.

        Out:
            The data length is info.tsize.

     **************************************************************************/

    public void[] next ( TypeInfo info, void[] dst )
    in
    {
        assert (dst.length == info.tsize);
    }
    out (data)
    {
        assert (data.ptr is dst.ptr);
        assert (data.length == dst.length);
    }
    body
    {
        return this.va_arg(info, dst);
    }

    /***************************************************************************

        Pops the next argument from the list and copies its value into dst.

        Params:
            dst = destination variable

        Returns:
            a pointer to dst.

        Out:
            The returned pointer points to dst.

     **************************************************************************/

    public T* nextT ( T ) ( out T dst )
    out (item)
    {
        assert (item is &dst);
    }
    body
    {
        return cast (T*) this.va_arg(typeid (T), (cast (void*) &dst)[0 .. dst.sizeof]).ptr;
    }

    /***************************************************************************

        Pops the next element from the argument list and discards it.

        Params:
            info = typeinfo of the next argument

     **************************************************************************/

    public void skip ( TypeInfo info )
    {
        return this.va_arg(info, null);
    }
}

scope class TypeInfoVaList : IVaList
{
    /***************************************************************************

        List of type information objects of the argument list elements.

     **************************************************************************/

    private const TypeInfo[] arguments;

    /***************************************************************************

        Number of remaining arguments.

     **************************************************************************/

    private uint n_remaining;

    /***************************************************************************

        Constructor

        Params:
            arguments  = list of argument typeinfos (_arguments)
            va_argsave = variadic argument list (__va_argsave)

     **************************************************************************/

    public this ( TypeInfo[] arguments, ref __va_argsave_t va_argsave )
    {
        this(arguments, va_argsave.va);
    }

    /***************************************************************************

        Constructor

        Params:
            arguments = list of argument typeinfos (_arguments)
            arglist   = variadic argument list (__va_argsave.va)

     **************************************************************************/

    public this ( TypeInfo[] arguments, ref __va_list arglist )
    {
        super(arglist);

        this.arguments = arguments;

        this.n_remaining = arguments.length;
    }

    /***************************************************************************

        Constructor

        Params:
            arguments = list of argument typeinfos (_arguments)
            arglist   = variadic argument list as obtained from va_start

     **************************************************************************/

    public this ( TypeInfo[] arguments, va_list arglist )
    {
        this(arguments, *cast (__va_list*) arglist);
    }

    /***************************************************************************

        Obtains the list of the typeinfos of the remaining arguments. The length
        of this list reflects the number of remaining arguments.
        (Slices an internal array, do not modify list elements in-place.)

        Returns:
            the list of the typeinfos of the remaining arguments.

     **************************************************************************/

    public TypeInfo[] remaining_typeinfos ( )
    {
        return this.arguments[$ - this.n_remaining .. $];
    }

    /***************************************************************************

        Obtains the typeinfo of the next argument. (Does not pop the argument
        from the list.)

        Returns:
            the typeinfo of the next argument.

     **************************************************************************/

    public TypeInfo next_typeinfo ( )
    in
    {
        assert (this.n_remaining, "no more arguments left");
    }
    body
    {
        return this.arguments[$ - this.n_remaining];
    }

    /***************************************************************************

        Returns:
            the total number of arguments as specified to the constructor.

     **************************************************************************/

    public size_t length ( )
    {
        return this.arguments.length;
    }

    /***************************************************************************

        Pops the next argument from the list and obtains its raw data.
        (It is an error to call this method when no arguments are left.)

        Params:
            info = output of argument type information

        Returns:
            a slice of the raw data of the argument popped from the list.

        In:
            There must be remaining arguments.

        Out:
            - info is not null.
            - The length of the returned data slice is info.tsize.

     **************************************************************************/

    public void[] next ( out TypeInfo info )
    in
    {
        assert (this.n_remaining, "no more arguments left");
    }
    out (data)
    {
        assert (info !is null);
        assert (data.length == info.tsize);
    }
    body
    {
        return this.va_arg(info = this.arguments[$ - this.n_remaining--]);
    }

    /***************************************************************************

        Pops the next argument from the list, if any, and discards it.
        (It is safe to call this method when no arguments are left.)

        Params:
            info = output of argument type information; will be null if there
                   was no argument left

        Returns:
            the number of remaining arguments.

     **************************************************************************/

    public size_t skip ( out TypeInfo info )
    {
        if (this.n_remaining)
        {
            this.va_arg(info = this.arguments[$ - this.n_remaining--], null);
        }

        return this.n_remaining;
    }

    /***************************************************************************

        Pops the next argument from the list, if any, and discards it.
        (It is safe to call this method when no arguments are left.)

        Returns:
            the number of remaining arguments.

     **************************************************************************/

    public size_t skip ( )
    {
        TypeInfo info;

        return this.skip(info);
    }

    /***************************************************************************

        'foreach' iteration over the remaining arguments. info is the type
        information and data the raw data of the current argument.

        It is safe to to do nested iterations and call any method during
        iteration.

     **************************************************************************/

    public int opApply ( int delegate ( ref TypeInfo info, ref void[] data ) dg )
    {
        int n = 0;

        while (this.n_remaining && !n)
        {
            TypeInfo info = this.arguments[$ - this.n_remaining--];

            void[] data = this.va_arg(info);

            n = dg(info, data);
        }

        return n;
    }
}

/*******************************************************************************

    Variadic arguments list base class for x86-64 DMD.

    Resembles tango.stdc.stdarg which unfortunately does not allow skipping
    arguments and popping an argument from the list without providing a buffer
    to copy the argument data to.

    In in most of the cases it is possible to simply slice the argument data.
    At all there are three possible locations where an argument can be passed:

    1. In memory (on the stack). In this case a simple pointer to the argument
       can be used.
    2. In one register. In this case the argument is automatically copied into
       __va_list.reg_args so one can use a pointer to the argument inside there.
    3. In two registers. Here the argument is scattered around two locations.
       However, since the maximum argument length is 16 bytes (TODO: is that
       true?) one can provide a ubyte[16] buffer, copy the two argument halves
       into it and use a pointer to that buffer.

*******************************************************************************/

abstract scope class IVaList
{
    /***************************************************************************

        Convenience type alias.

     **************************************************************************/

    alias .__va_argsave_t __va_argsave_t;

    /***************************************************************************

        Variable argument list.

     **************************************************************************/

    private __va_list* arglist;

    /***************************************************************************

        Buffer for arguments passed in two registers.

     **************************************************************************/

    private ubyte[size_t.sizeof * 2] buffer;

    /***************************************************************************

        Constructor

        Params:
            va_argsave = variadic argument list (__va_argsave)

     **************************************************************************/

    protected this ( ref __va_argsave_t va_argsave )
    {
        this(va_argsave.va);
    }

    /***************************************************************************

        Constructor

        Params:
            arglist = variadic argument list (__va_argsave.va)

     **************************************************************************/

    protected this ( ref __va_list arglist )
    {
        this.arglist = &arglist;
    }

    /***************************************************************************

        Constructor

        Params:
            arglist = variadic argument list as obtained from va_start

     **************************************************************************/

    protected this ( va_list arglist )
    {
        this(*cast (__va_list*) arglist);
    }

    /***************************************************************************

        Pops the next argument from the list.

        Params:
            ti = typeinfo of the next argument

        Returns:
            argument data.

        Out:
            The data length is ti.tsize.

     **************************************************************************/

    protected void[] va_arg(TypeInfo ti)
    out (data)
    {
        assert(data.length == ti.tsize);
    }
    body
    {
        return this.va_arg(ti, this.buffer[0 .. ti.tsize]);
    }

    /***************************************************************************

        Pops the next argument from the list and copies its raw data into dst if
        dst.length is non-zero or discards it if dst is empty or null.

        Params:
            ti  = typeinfo of the next argument
            dst = destination buffer or a null or empty array

        Returns:
            dst, which contains the argument data if not empty/null.

        In:
            dst.length must be info.tsize or zero.

        Out:
            The returned array is dst.

     **************************************************************************/

    protected void[] va_arg(TypeInfo ti, void[] dst)
    in
    {
        assert (!dst.length || dst.length == ti.tsize);
    }
    out (parmn_out)
    {
        assert (parmn_out.ptr is dst.ptr);
        assert (parmn_out.length == dst.length);
    }
    body
    {
        TypeInfo arg1, arg2;
        auto ok = !ti.argTypes(arg1, arg2);
        assert(ok, "not a valid argument type for va_arg");

        if (arg1 && arg1.tsize <= 8)
        {   // Arg is passed in one register
            auto stack = false,
                 offset_fpregs_save = this.arglist.offset_fpregs,
                 offset_regs_save   = this.arglist.offset_regs;

            L1: void[] data = this.va_regparm(arg1, stack, stack = true);

            if (dst.length)
            {
                dst[0 .. data.length] = data[];
            }

            if (arg2)
            {
                bool redo = false;

                data = this.va_regparm(arg2, stack,
                                       {
                                           redo = !stack;
                                           return stack;
                                       }());

                if (redo)
                {   // arg1 is really on the stack, so rewind and redo
                    this.arglist.offset_fpregs = offset_fpregs_save;
                    this.arglist.offset_regs = offset_regs_save;
                    stack = true;
                    goto L1;
                }

                if (dst.length)
                {
                    dst[8 .. $] = data[];
                }
            }
        }
        else
        {   // Always passed in memory
            // The arg may have more strict alignment than the stack

            void[] data = this.va_memparm(ti);

            if (dst.length)
            {
                dst[] = data[];
            }
        }

        return dst;
    }

    /***************************************************************************

        Obtains the data of an argument passed in memory (on the stack).

        Params:
            ti  = argument typeinfo

        Returns:
            argument data

     **************************************************************************/

    private void[] va_memparm ( TypeInfo ti )
    {
        void[] data = (cast(void*)
                       this.roundUp(cast(size_t)this.arglist.stack_args,
                                    ti.talign))[0 .. ti.tsize];

        this.arglist.stack_args = cast(void*)
                                (cast(size_t)data.ptr +
                                 this.roundUp(data.length, size_t.sizeof));

        return data;
    }

    /***************************************************************************

        Obtains the data of an argument passed in a register.

        Params:
            ti        = argument typeinfo
            stack     = true if the argument is for sure located on the stack
                        even if the arglist.offset_(f)pregs indicates it is in
                        a register
            set_stack = evaluated if arglist.offset_(f)pregs and/or stack
                        indicate that the argument is on the stack; should
                        return true to use the stack argument or false to do
                        nothing

        Returns:
            argument data or null if set_stack returned false.

     **************************************************************************/

    private void[] va_regparm(TypeInfo ti, bool stack, lazy bool set_stack)
    {
        void* p;
        auto tsize = ti.tsize();

        with (*this.arglist) if (ti is typeid(double)  || ti is typeid(float) ||
                                 ti is typeid(idouble) || ti is typeid(ifloat))
        {   // Passed in XMM register
            if (offset_fpregs < (__va_argsave_t.regs.sizeof +  __va_argsave_t.fpregs.sizeof) && !stack)
            {
                p = reg_args + offset_fpregs;
                offset_fpregs += __va_argsave_t.fpregs[0].sizeof;
            }
            else if (set_stack)
            {
                p = stack_args;
                stack_args += this.roundUp(tsize, size_t.sizeof);
            }
            else
            {
                return null;
            }
        }
        else
        {   // Passed in regular register
            if (offset_regs < __va_argsave_t.regs.sizeof && !stack)
            {
                p = reg_args + offset_regs;
                offset_regs += __va_argsave_t.regs[0].sizeof;
            }
            else if (set_stack)
            {
                p = stack_args;
                stack_args += size_t.sizeof;
            }
            else
            {
                return null;
            }
        }

        return p[0 .. tsize];
    }

    /***************************************************************************

        Calculates the least integer multiple of q greater than or equal to n.

        Params:
            n = number to round up to the next integer multiple of b
            q = quantiser

        Returns:
            n rounded up to the next integer multiple of q.

     **************************************************************************/

    private static size_t roundUp ( size_t n, size_t q )
    {
        q--;

        return (n + q) & ~q;
    }
}
