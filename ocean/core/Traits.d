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

    Tells whether the passed string is a valid D 1.0 identifier.

    This function is designed to be used at compile time.

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

    if ( string.length == 0 ) return false;

    if ( !alphaUnderscore(string[0]) ) return false;

    if ( string.length == 1 && string[0] == '_' ) return false;

    if ( string.length > 1 && string[0] == '_' && string[1] == '_' ) return false;

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

    Template to determine if a type tuple is composed of unique types, with no
    duplicates.

    Template parameter:
        Tuple = variadic type tuple

    Evaluates to:
        true if no duplicate types exist in Tuple

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

    Strips the typedef off T.

    Template params::
        T = type to strip of typedef

    Evaluates to:
        alias to either T (if T is not typedeffed) or the base class of T

*******************************************************************************/

public template StripTypedef ( T )
{
    static if ( is ( T Orig == typedef ) )
    {
        alias Orig StripTypedef;
    }
    else
    {
        alias T StripTypedef;
    }
}

