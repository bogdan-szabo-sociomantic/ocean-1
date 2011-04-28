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

