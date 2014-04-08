/*******************************************************************************

    Useful functions & templates.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    More of the kind of thing you'd find in tango.core.Traits...

*******************************************************************************/

module ocean.core.Traits;

/*******************************************************************************

    Imports.

*******************************************************************************/

private import tango.core.Tuple: Tuple;

/*******************************************************************************

    Tells whether the passed string is a D 1.0 keyword.

    This function is designed to be used at compile time.

    Note that any string identifier beginning with __ is also reserved by D 1.0.
    This function does not check for this case.

    Params:
        string = string to check

    Returns:
        true if the string is a D 1.0 keyword

*******************************************************************************/

public bool isKeyword ( char[] string )
{
    const char[][] keywords = [
        "abstract",     "alias",        "align",        "asm",
        "assert",       "auto",         "body",         "bool",
        "break",        "byte",         "case",         "cast",
        "catch",        "cdouble",      "cent",         "cfloat",
        "char",         "class",        "const",        "continue",
        "creal",        "dchar",        "debug",        "default",
        "delegate",     "delete",       "deprecated",   "do",
        "double",       "else",         "enum",         "export",
        "extern",       "false",        "final",        "finally",
        "float",        "for",          "foreach",      "foreach_reverse",
        "function",     "goto",         "idouble",      "if",
        "ifloat",       "import",       "in",           "inout",
        "int",          "interface",    "invariant",    "ireal",
        "is",           "lazy",         "long",         "macro",
        "mixin",        "module",       "new",          "null",
        "out",          "override",     "package",      "pragma",
        "private",      "protected",    "public",       "real",
        "ref",          "return",       "scope",        "short",
        "static",       "struct",       "super",        "switch",
        "synchronized", "template",     "this",         "throw",
        "true",         "try",          "typedef",      "typeid",
        "typeof",       "ubyte",        "ucent",        "uint",
        "ulong",        "union",        "unittest",     "ushort",
        "version",      "void",         "volatile",     "wchar",
        "while",        "with"
    ];

    for ( int i; i < keywords.length; i++ )
    {
        if ( string == keywords[i] ) return true;
    }
    return false;
}



/*******************************************************************************

    Tells whether the passed string is a valid D 1.0 identifier.

    This function is designed to be used at compile time.

    Note that this function does not check whether the passed string is a D
    keyword (see isKeyword(), above) -- all keywords are also identifiers.

    Params:
        string = string to check

    Returns:
        true if the string is a valid D 1.0 identifier

*******************************************************************************/

public bool isIdentifier ( char[] string )
{
    bool alphaUnderscore ( char c )
    {
        return c == '_' || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z');
    }

    bool validChar ( char c )
    {
        return alphaUnderscore(c) || (c >= '0' && c <= '9');
    }

    // Identifiers must have a length
    if ( string.length == 0 ) return false;

    // Identifiers must begin with an alphabetic or underscore character
    if ( !alphaUnderscore(string[0]) ) return false;

    // Strings beginning with "__" are reserved (not identifiers)
    if ( string.length > 1 && string[0] == '_' && string[1] == '_' ) return false;

    // All characters after the first must be alphanumerics or underscores
    for ( int i = 1; i < string.length; i++ )
    {
        if ( !validChar(string[i]) ) return false;
    }

    return true;
}



/*******************************************************************************

    Template which evaluates to true if the specified type is a compound type
    (ie a class, struct or union).

    Template params:
        T = type to check

    Evaluates to:
        true if T is a compound type, false otherwise

*******************************************************************************/

public template isCompoundType ( T )
{
    static if ( is(T == struct) || is(T == class) || is(T== union) )
    {
        const isCompoundType = true;
    }
    else
    {
        const isCompoundType = false;
    }
}



/*******************************************************************************

    Template to get the type tuple of compound type T.

    Template params:
        T = type to get type tuple of

    Evaluates to:
        type tuple of T's members

*******************************************************************************/

public template TypeTuple ( T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "TypeTuple!(" ~ T.stringof ~ "): type is not a struct / class / union");
    }

    alias typeof(T.tupleof) TypeTuple;
}



/*******************************************************************************

    Template to get the type of the ith data member struct/class T.

    Template params:
        T = type to get field of

    Evaluates to:
        type of ith member of T

*******************************************************************************/

public template FieldType ( T, size_t i )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldType!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    alias typeof (T.tupleof)[i] FieldType;
}



/*******************************************************************************

    Gets a pointer to the ith member of a struct/class.

    Template params:
        i = index of member to get
        T = type of compound to get member from

    Params:
        t = pointer to compound to get member from

    Returns:
        pointer to ith member

*******************************************************************************/

public FieldType!(T, i)* GetField ( size_t i, T ) ( T* t )
{
    return GetField!(i, FieldType!(T, i), T)(t);
}



/*******************************************************************************

    Gets a pointer to the ith member of a struct/class.

    Template params:
        i = index of member to get
        M = type of member
        T = type of compound to get member from

    Params:
        t = pointer to compound to get member from

    Returns:
        pointer to ith member

*******************************************************************************/

public M* GetField ( size_t i, M, T ) ( T* t )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "GetField!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    return cast(M*)((cast(void*)t) + T.tupleof[i].offsetof);
}



/*******************************************************************************

    Template to get the name of the ith member of a struct / class.

    Template parameter:
        i = index of member to get
        T = type of compound to get member name from

    Evaluates to:
        name of the ith member

*******************************************************************************/

public template FieldName ( size_t i, T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldName!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    const FieldName = StripFieldName!(T.tupleof[i].stringof);
}



/*******************************************************************************

    Template to strip the part after the '.' in a string.

    Template parameter:
        name = string to scan
        n = scanning index

    Evaluates to:
        tail of name after the last '.' character

*******************************************************************************/

private template StripFieldName ( char[] name, size_t n = size_t.max )
{
    static if ( n >= name.length )
    {
        const StripFieldName = StripFieldName!(name, name.length - 1);
    }
    else static if ( name[n] == '.' )
    {
        const StripFieldName = name[n + 1 .. $];
    }
    else static if ( n )
    {
        const StripFieldName = StripFieldName!(name, n - 1);
    }
    else
    {
        const StripFieldName = name;
    }
}



/*******************************************************************************

    Template to get the size in bytes of the passed type tuple.

    Template parameter:
        Tuple = variadic type tuple

    Evaluates to:
        size_t constant equal to the sizeof each type in the tuple

*******************************************************************************/

public template SizeofTuple ( Tuple ... )
{
    static if ( Tuple.length > 0 )
    {
        const size_t SizeofTuple = Tuple[0].sizeof + SizeofTuple!(Tuple[1..$]);
    }
    else
    {
        const size_t SizeofTuple = 0;
    }
}


/*******************************************************************************

    Function which iterates over the type tuple of T and copies all fields from
    one instance to another. Note that, for classes, according to:

        http://digitalmars.com/d/1.0/class.html

    "The .tupleof property returns an ExpressionTuple of all the fields in the
    class, excluding the hidden fields and the fields in the base class."

    (This is not actually true with current versions of the compiler, but
    anyway.)

    Template params:
        T = type of instances to copy fields from and to

    Params:
        dst = instance of type T to be copied into
        src = instance of type T to be copied from

*******************************************************************************/

public void copyFields ( T ) ( ref T dst, ref T src )
{
    foreach ( i, t; typeof(dst.tupleof) )
    {
        dst.tupleof[i] = src.tupleof[i];
    }
}


/*******************************************************************************

    Function which iterates over the type tuple of T and sets all fields of the
    provided instance to their default (.init) values. Note that, for classes,
    according to:

        http://digitalmars.com/d/1.0/class.html

    "The .tupleof property returns an ExpressionTuple of all the fields in the
    class, excluding the hidden fields and the fields in the base class."

    (This is not actually true with current versions of the compiler, but
    anyway.)

    Template params:
        T = type of instances to initialise

    Params:
        o = instance of type T to be initialised

*******************************************************************************/

public void initFields ( T ) ( ref T o )
{
    foreach ( i, t; typeof(o.tupleof) )
    {
        o.tupleof[i] = o.tupleof[i].init;
    }
}


/*******************************************************************************

    Template to determine if a type tuple is composed of unique types, with no
    duplicates.

    Template parameter:
        Tuple = variadic type tuple

    Evaluates to:
        true if no duplicate types exist in Tuple

    TODO: could be re-phrased in terms of tango.core.Tuple : Unique

*******************************************************************************/

public template isUniqueTypesInTuple ( Tuple ... )
{
    static if ( Tuple.length > 1 )
    {
        const bool isUniqueTypesInTuple = (CountTypesInTuple!(Tuple[0], Tuple) == 1) && isUniqueTypesInTuple!(Tuple[1..$]);
    }
    else
    {
        const bool isUniqueTypesInTuple = true;
    }
}



/*******************************************************************************

    Template to count the number of times a specific type appears in a tuple.

    Template parameter:
        Type = type to count
        Tuple = variadic type tuple

    Evaluates to:
        number of times Type appears in Tuple

    TODO: could be re-phrased in terms of tango.core.Tuple : Unique

*******************************************************************************/

public template CountTypesInTuple ( Type, Tuple ... )
{
    static if ( Tuple.length > 0 )
    {
        const uint CountTypesInTuple = is(Type == Tuple[0]) + CountTypesInTuple!(Type, Tuple[1..$]);
    }
    else
    {
        const uint CountTypesInTuple = 0;
    }
}


/*******************************************************************************

    Determines if T is a typedef.

    Template params:
        T = type to check

    Evaluates to:
        true if T is a typedef, false otherwise

*******************************************************************************/

public template isTypedef (T)
{
    static if (is(T Orig == typedef))
    {
        const bool isTypedef = true;
    }
    else
    {
        const bool isTypedef = false;
    }
}

unittest
{
    typedef double RealNum;

    static assert(!isTypedef!(int));
    static assert(!isTypedef!(double));
    static assert(isTypedef!(RealNum));
}


/*******************************************************************************

    Strips the typedef off T.

    Template params:
        T = type to strip of typedef

    Evaluates to:
        alias to either T (if T is not typedeffed) or the base class of T

*******************************************************************************/

public template StripTypedef ( T )
{
    static if ( is ( T Orig == typedef ) )
    {
        alias StripTypedef!(Orig) StripTypedef;
    }
    else
    {
        alias T StripTypedef;
    }
}

unittest
{
    typedef int Foo;
    typedef Foo Bar;
    typedef Bar Goo;

    static assert(is(StripTypedef!(Goo) == int));
}


/******************************************************************************

    Tells whether the types in T are or contain dynamic arrays, recursing into
    the member types of structs and union, the element types of dynamic and
    static arrays and typedefs.

    Reference types other than dynamic arrays (classes, pointers, functions,
    delegates and associative arrays) are ignored and not recursed into.

    Template parameter:
        T = types to check

    Evaluates to:
        true if any type in T is a or contains dynamic arrays or false if not
        or T is empty.

 ******************************************************************************/

template ContainsDynamicArray ( T ... )
{
    static if (T.length)
    {
        static if (is (T[0] Base == typedef))
        {
            // Recurse into typedef.

            const ContainsDynamicArray = ContainsDynamicArray!(Base, T[1 .. $]);
        }
        else static if (is (T[0] == struct) || is (T[0] == union))
        {
            // Recurse into struct/union members.

            const ContainsDynamicArray = ContainsDynamicArray!(typeof (T[0].tupleof)) ||
                                         ContainsDynamicArray!(T[1 .. $]);
        }
        else
        {
            static if (is (T[0] Element : Element[])) // array
            {
                static if (is (T[0] == Element[])) // dynamic array
                {
                    const ContainsDynamicArray = true;
                }
                else
                {
                    // Static array, recurse into base type.

                    const ContainsDynamicArray = ContainsDynamicArray!(Element) ||
                                                 ContainsDynamicArray!(T[1 .. $]);
                }
            }
            else
            {
                // Skip non-dynamic or static array type.

                const ContainsDynamicArray = ContainsDynamicArray!(T[1 .. $]);
            }
        }
    }
    else
    {
        const ContainsDynamicArray = false;
    }
}


/*******************************************************************************

    Evaluates, if T is callable (function, delegate, a class/interface/struct/
    union implementing opCall() as a member or static method or a typedef of
    these), to a type tuple with the return type as the first element, followed
    by the argument types.
    Evaluates to an empty tuple if T is not callable.

    Template parameter:
        T = Type to, if callable, get the return and argument types

    Evaluates to:
        a type tuple containing the return and argument types or an empty tuple
        if T is not callable.

*******************************************************************************/

template ReturnAndArgumentTypesOf ( T )
{
    static if (is(T Args == function) && is(T Return == return))
    {
        alias Tuple!(Return, Args) ReturnAndArgumentTypesOf;
    }
    else static if (is(T F == delegate) || is(T F == F*) ||
                    is(T F == typedef)  || is(typeof(&(T.init.opCall)) F))
    {
        alias ReturnAndArgumentTypesOf!(F) ReturnAndArgumentTypesOf;
    }
    else
    {
        alias Tuple!() ReturnAndArgumentTypesOf;
    }
}

/******************************************************************************/

unittest
{
    static assert(is(ReturnAndArgumentTypesOf!(void) == Tuple!()));
    static assert(is(ReturnAndArgumentTypesOf!(int) == Tuple!()));
    static assert(is(ReturnAndArgumentTypesOf!(void function()) == Tuple!(void)));
    static assert(is(ReturnAndArgumentTypesOf!(int function(char)) == Tuple!(int, char)));
    static if (is(int function(char) T: T*))
    {
        static assert(is(ReturnAndArgumentTypesOf!(T) == Tuple!(int, char)));
    }
    static assert(is(ReturnAndArgumentTypesOf!(int delegate(char)) == Tuple!(int, char)));

    class C {int opCall(char){return 0;}}
    class D {static int opCall(char){return 0;}}
    class E {int opCall;}
    interface I {int opCall(char);}
    struct S {int opCall(char){return 0;}}
    union U {int opCall(char){return 0;}}

    static assert(is(ReturnAndArgumentTypesOf!(C) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(D) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(E) == Tuple!()));
    static assert(is(ReturnAndArgumentTypesOf!(I) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(S) == Tuple!(int, char)));
    static assert(is(ReturnAndArgumentTypesOf!(U) == Tuple!(int, char)));
}
