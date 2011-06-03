/*******************************************************************************

    Useful functions & templates.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        April 2011: Initial release

    authors:        Gavin Norman

    More of the kind of thing you'd find in tango.core.Traits...

*******************************************************************************/

module ocean.core.Traits;



/*******************************************************************************

    Tells whether the passed string is a D 1.0 keyword.

    This function is designed to be used at compile time.

    Params:
        string = string to check

    Returns:
        true if the string is a D 1.0 keyword

*******************************************************************************/

public bool isKeyword ( char[] string )
{
    const char[][] keywords = [
        "__FILE__",     "__gshared",    "__LINE__",     "__thread",     "__traits",
        "abstract",     "alias",        "align",        "asm",          "assert",
        "auto",         "body",         "bool",         "break",        "byte",
        "case",         "cast",         "catch",        "cdouble",      "cent",
        "cfloat",       "char",         "class",        "const",        "continue",
        "creal",        "dchar",        "debug",        "default",      "delegate",
        "delete",       "deprecated",   "do",           "double",       "else",
        "enum",         "export",       "extern",       "false",        "final",
        "finally",      "float",        "for",          "foreach",      "foreach_reverse",
        "function",     "goto",         "idouble",      "if",           "ifloat",
        "import",       "in",           "inout",        "int",          "interface",
        "invariant",    "ireal",        "is",           "lazy",         "long",
        "macro",        "mixin",        "module",       "new",          "null",
        "out",          "override",     "package",      "pragma",       "private",
        "protected",    "public",       "real",         "ref",          "return",
        "scope",        "shared",       "short",        "static",       "struct",
        "super",        "switch",       "synchronized", "template",     "this",
        "throw",        "true",         "try",          "typedef",      "typeid",
        "typeof",       "ubyte",        "ucent",        "uint",         "ulong",
        "union",        "unittest",     "ushort",       "version",      "void",
        "volatile",     "wchar",        "while",        "with"
    ];

    for ( int i; i < keywords.length; i++ )
    {
        if ( string == keywords[i] ) return true;
    }
    return false;
}



/*******************************************************************************

    Template which evaluates to true if the specified type is a compound type
    (ie a class or struct).

    TODO: do unions count as compound types?

    Template params:
        T = type to check

    Evaluates to:
        true if T is a compound type, false otherwise

*******************************************************************************/

public template isCompoundType ( T )
{
    static if ( is(T == struct) || is(T == class) )
    {
        const isCompoundType = true;
    }
    else
    {
        const isCompoundType = false;
    }
}



/*******************************************************************************

    Template to get the type tuple of struct/class T.

    Template params:
        T = type to get type tuple of

    Evaluates to:
        type tuple of T's members

*******************************************************************************/

public template FieldTypeTuple ( T )
{
    static if ( !isCompoundType!(T) )
    {
        static assert(false, "FieldTypeTuple!(" ~ T.stringof ~ "): type is not a struct / class");
    }

    alias typeof(T.tupleof) FieldTypeTuple;
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

public FieldType!(S, i)* GetField ( size_t i, T ) ( T* t )
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

    return cast(M*)((cast(void*)s) + T.tupleof[i].offsetof);
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

