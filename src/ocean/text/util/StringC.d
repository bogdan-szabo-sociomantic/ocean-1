/*******************************************************************************

    Module for conversion between strings in C and D. Needed for C library
    bindings.

    --

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        October 2010: Initial release

    author:         David Eckardt

    --

    Description:

    --

    Usage:

    ---

        mstring text;

        char* cText = StringC.toCString(text);
        mstring text = StringD.toDString(cText);

    ---

*******************************************************************************/

module ocean.text.util.StringC;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.transition;

import ocean.stdc.string: strlen, wcslen;
import ocean.stdc.stddef: wchar_t;


/*******************************************************************************

    Class containing the string conversion functions

*******************************************************************************/

class StringC
{
    /***************************************************************************

        Wide character type alias (platform dependent)

     **************************************************************************/

    public alias wchar_t Wchar;

    /***************************************************************************

        Null terminators

     **************************************************************************/

    public const char  Term  = '\0';
    public const Wchar Wterm = '\0';

    /***************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to the original string. A pointer to the
        string is returned.

        Params:
            str = input string

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    public static char* toCstring ( ref mstring str )
    {
        if (str.length && !!str[$ - 1])
        {
            str ~= StringC.Term;
        }

        return str.ptr;
    }

    /***************************************************************************

        Converts str to a C string, that is, if a null terminator is not
        present then it is appended to the original string. A pointer to the
        string is returned.

        Params:
            str = input string

        Returns:
            C compatible (null terminated) string

    ***************************************************************************/

    public static Wchar* toCstring ( ref Wchar[] str )
    {
        if (str.length && !!str[$ - 1])
        {
            str ~= StringC.Wterm;
        }

        return str.ptr;
    }

    /***************************************************************************

        Converts str to a D string: str is sliced from the beginning up to its
        null terminator.

        Params:
            str = C compatible input string (pointer to the first character of
                the null terminated string)

        Returns:
            D compatible (non-null terminated) string

    ***************************************************************************/

    public static cstring toDString ( char* str )
    {
        return str ? str[0 .. strlen(str)] : "";
    }

    /***************************************************************************

        Converts str to a D string: str is sliced from the beginning up to its
        null terminator.

        Params:
            str = C compatible input string (pointer to the first character of
                the null terminated string)

        Returns:
            D compatible (non-null terminated) string

    ***************************************************************************/

    public static Const!(Wchar)[] toDString ( Wchar* str )
    {
        return str ? str[0 .. wcslen(str)] : "";
    }
}
