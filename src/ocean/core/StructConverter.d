/******************************************************************************

    Struct Converter functions

    copyright:      Copyright (c) 2014 sociomantic labs. All rights reserved

    version:        February 2014: Initial release

    author:         Mathias Baumann

    Functions to make converting an instance to a similar but not equal type
    easier.

 ******************************************************************************/

module ocean.core.StructConverter;

private import ocean.core.Traits,
               tango.core.Traits;

/***************************************************************************

    Copies members of the same name from <From> to <To>.

    Given a variable in <To> called 'example_var', if a convert function in <To>
    exists with the name 'convert_example_var', then this function will be
    called and no automatic conversion will happen for that variable. The
    function must have one of the following signatures:
    ---
    void delegate ( ref <From>, void[] delegate ( size_t ) )
    void delegate ( ref <From> )
    void delegate ( );
    ---
    The delegate passed to the first can be used to allocate temporary buffers
    that the convert function might need to do its converting.

    If no convert function exists and the types differ, various things happen:

    * For structs it calls this function again
    * For dynamic arrays, a temporary array of the same length is created and
      this function is called for every element of the array
    * For static arrays the same happens, just without a temporary allocation

    If the types are the same a simple assignment will be done. The types have
    to match exactly, implicit conversions are not supported.

    It is an error if a variable in <To> doesn't exist in <From> and no convert
    function for it exists,

    Note: Dynamic arrays of the same type will actually reference the same
          memory where as arrays of similar types that were converted use memory
          provided by the requestBuffer delegate.

    Template Parameters:
        From = type we're copying from
        To   = type we're copying to

    Parameters:
        from          = instance we're copying from
        to            = instance we're copying to
        requestBuffer = delegate to request temporary buffers used during
                        conversion.

***************************************************************************/

public void structCopy ( From, To ) ( ref From from, out To to,
                                      void[] delegate ( size_t ) requestBuffer )
{
    static assert ( is ( From == struct ) && is ( To == struct ),
            "structCopy works only on structs, not on " ~
            From.stringof ~ " / " ~ To.stringof);

    foreach ( to_index, to_member; to.tupleof )
    {
        const convFuncName = "convert_" ~ FieldName!(to_index, To);

        static if ( structHasMember!(convFuncName, To)() )
        {
            callBestOverload!(From, To, convFuncName)(from, to, requestBuffer);
        }
        else static if ( structHasMember!(FieldName!(to_index, To), From)() )
        {
            auto from_field = getField!(FieldName!(to_index, To))(from);
            auto to_field = &to.tupleof[to_index];

            copyField(from_field, to_field, requestBuffer);
        }
        else
        {
            static assert ( false, "Unhandled field: " ~
                            FieldName!(to_index, To) ~ " of types " ~
                            typeof(to_member).stringof ~ " " ~
                            typeof(*from_field).stringof);
        }
    }
}

/*******************************************************************************

    Helper function for structCopy().

    Copies a field to another field, doing a conversion if required and
    possible.

    Template Params:
        From = type of field we copy/convert from
        To   = type of field we copy/convert to

    Params:
        from_field = pointer to the field we want to copy/convert from
        to_field   = pointer to the field we want to copy/convert to
        requestBuffer = delegate to request temporary memory for doing
                        conversions

*******************************************************************************/

private void copyField ( From, To ) ( From* from_field, To* to_field,
                                      void[] delegate ( size_t ) requestBuffer )
{
    static if ( is ( typeof(*to_field) : typeof(*from_field) ) )
    {
        static if ( isStaticArrayType!(typeof((*to_field))) )
        {
            (*to_field)[] = (*from_field)[];
        }
        else
        {
            *to_field = *from_field;
        }
    }
    else static if ( is ( typeof((*to_field)) == struct ) &&
                     is ( typeof(*from_field) == struct ) )
    {
        alias structCopy!(typeof(*from_field), typeof((*to_field))) copyMember;

        copyMember(*from_field, *to_field,
                   requestBuffer);
    }
    else static if (isStaticArrayType!(typeof((*to_field))) &&
                    isStaticArrayType!(typeof(*from_field)))
    {
        alias BaseTypeOfArrays!(typeof(*to_field))   ToBaseType;
        alias BaseTypeOfArrays!(typeof(*from_field)) FromBaseType;

        static if ( is(ToBaseType == struct) &&
                    is(FromBaseType == struct) )
        {
            foreach ( i, ref el; *to_field )
            {
                structCopy!(FromBaseType, ToBaseType)((*from_field)[i],
                                                       el, requestBuffer);
            }
        }
        else
        {
            static assert (1==0, "Unsupported auto-struct-conversion " ~
                FromBaseType.stringof ~ " -> " ~ ToBaseType.stringof ~
                ". Please provide the convert function " ~ To.stringof ~
                 "." ~ convertToFunctionName(FieldName!(to_index, To)));
        }
    }
    else static if (isDynamicArrayType!(typeof((*to_field))) &&
                    isDynamicArrayType!(typeof(*from_field)))
    {
        alias BaseTypeOfArrays!(typeof(*to_field))   ToBaseType;
        alias BaseTypeOfArrays!(typeof(*from_field)) FromBaseType;

        static if ( is(ToBaseType == struct) &&
                    is(FromBaseType == struct) )
        {
            if ( from_field.length > 0 )
            {
                auto buf = requestBuffer(from_field.length * ToBaseType.sizeof);

                *to_field = (cast(ToBaseType*)buf)[0 .. from_field.length];

                foreach ( i, ref el; *to_field )
                {
                    structCopy!(FromBaseType, ToBaseType)((*from_field)[i],
                                                          el, requestBuffer);
                }
            }
            else
            {
                *to_field = null;
            }
        }
        else
        {
            static assert (false, "Unsupported auto-struct-conversion " ~
                FromBaseType.stringof ~ " -> " ~ ToBaseType.stringof ~
                ". Please provide the convert function " ~ To.stringof ~
                 "." ~ convertToFunctionName(FieldName!(to_index, To)));
        }
    }
    else
    {
        // Workaround for error-swallowing DMD bug
        // https://github.com/sociomantic/dmd/issues/20
        pragma(msg, "Unhandled field: " ~
                    FieldName!(to_index, To) ~ " of types " ~ To.stringof ~ "." ~
                        typeof((*to_field)).stringof ~ " " ~ From.stringof ~ "." ~
                        typeof(*from_field).stringof);

        static assert ( false, "Unhandled field: " ~
                        FieldName!(to_index, To) ~ " of types " ~
                        typeof((*to_field)).stringof ~ " " ~
                        typeof(*from_field).stringof);
    }
}

/*******************************************************************************

    Checks whether struct S has a member (variable or method) of the given name

    Template Params:
        name = name to check for
        S    = struct to check

    Returns:
        true if S has queried member, else false

*******************************************************************************/

private bool structHasMember ( char[] name, S ) ( )
{
    mixin(`
        static if (is(typeof(S.` ~ name ~`)))
        {
            return true;
        }
        else
        {
            return false;
        }`);
}

/*******************************************************************************

    Calls the function given in function_name in struct To.
    The function must have one of the following signatures:
    ---
    void delegate ( ref <From>, void[] delegate ( size_t ) )
    void delegate ( ref <From> )
    void delegate ( );
    ---

    Template Params:
        From = type of the struct that will be passed to the function
        To   = type of the struct that has to have that function
        function_name = name of the function that To must have

    Params:
        from = struct instance that will be passed to the function
        to   = struct instance that should have said function declared
        requestBuffer = memory request method that the function can use (it
                        should not allocate memory itself)

*******************************************************************************/

private void callBestOverload ( From, To, char[] function_name )
           ( ref From from, ref To to, void[] delegate ( size_t ) requestBuffer )
{
     mixin (`
        static if ( is ( typeof(&to.`~function_name~`)
                       == void delegate ( ref From, void[] delegate ( size_t ) ) ))
        {
            to.`~function_name~ `(from, requestBuffer);
        }
        else static if ( is ( typeof(&to.`~function_name~`)
                                                   == void delegate ( ref From ) ))
        {
            to.`~function_name~ `(from);
        }
        else static if ( is ( typeof(&to.`~function_name~`) == void delegate ( ) ))
        {
            to.`~function_name~ `();
        }
        else
        {
            const convFuncTypeString = typeof(&to.`~function_name~`).stringof;
            static assert ( false,
              "Function ` ~
             To.stringof ~ `.` ~ function_name ~
             ` (" ~ convFuncTypeString ~ ") doesn't `
             `have any of the accepted types `
             `'void delegate ( ref "~From.stringof~", void[] delegate ( size_t ) )' or `
             `'void delegate ( ref "~From.stringof~" )' or `
             `'void delegate ( )'" );
        }`);

}

/*******************************************************************************

    aliases to the type of the member <name> in the struct <Struct>

    Template Params:
        name = name of the member you want the type of
        Struct = struct that <name> is member of

*******************************************************************************/

private template TypeOf ( char[] name, Struct )
{
    mixin(`alias typeof(Struct.`~name~`) TypeOf;`);
}

/*******************************************************************************

    Returns a pointer to the field <field_name> defined in the struct <Struct>

    Template Params:
        field_name = name of the field in the struct <Struct>
        Struct     = struct that is expected to have a member called
                     <field_name>

    Returns:
        pointer to the field <field_name> defined in the struct <Struct>

*******************************************************************************/

private TypeOf!(field_name, Struct)* getField ( char[] field_name, Struct )
                                              ( ref Struct s )
{
    mixin(`
        static if ( is ( typeof(Struct.`~field_name~`) ) )
        {
            return &(s.`~field_name~`);
        }
        else
        {
            return null;
        }`);
}


unittest
{
    struct A
    {
        int a;
        int b;
        short c;
    }

    struct B
    {
        short c;
        int a;
        int b;
    }

    void[] buf ( size_t s )
    {
        return new ubyte[s];
    }

    auto a = A(1,2,3);
    B b;

    structCopy(a, b, &buf);

    assert ( a.a == b.a, "a != a" );
    assert ( a.b == b.b, "b != b" );
    assert ( a.c == b.c, "c != c" );
}


unittest
{
    struct A
    {
        int a;
        int b;
        int[][] i;
        int c;
        char[] the;

        struct AA
        {
            int b;
        }

        AA srt;
    }

    struct B
    {
        int c;
        short b;
        int a;
        short d;
        char[] the;
        int[][] i;

        struct AB
        {
            int b;
            int c;

            void convert_c () {}

        }

        AB srt;

        void convert_b ( ref A structa )
        {
            this.b = cast(short) structa.b;
        }

        void convert_d ( ref A structa)
        {
            this.d = structa.a;
        }
    }

    auto a = A(1,2, [[1,2], [45,234], [53],[3]],3, "THE TEH THE RTANEIARTEN");
    B b_loaded;

    void[] buf ( size_t t )
    {
        return new ubyte[t];
    }

    structCopy!(A, B)(a, b_loaded, &buf);

    assert ( b_loaded.a == a.a, "Conversion failure" );
    assert ( b_loaded.b == a.b, "Conversion failure" );
    assert ( b_loaded.c == a.c, "Conversion failure" );
    assert ( b_loaded.d == a.a, "Conversion failure" );
    assert ( b_loaded.the[] == a.the[], "Conversion failure" );
    assert ( b_loaded.the.ptr == a.the.ptr, "Conversion failure" );
    assert ( b_loaded.i.ptr == a.i.ptr, "Conversion failure" );
    assert ( b_loaded.i[0][] == a.i[0][], "Nested array mismatch" );
    assert ( b_loaded.i[1][] == a.i[1][], "Nested array mismatch" );
    assert ( b_loaded.i[2][] == a.i[2][], "Nested array mismatch" );
    assert ( b_loaded.i[3][] == a.i[3][], "Nested array mismatch" );
}
