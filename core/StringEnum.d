/*******************************************************************************

    String enum template class, encapsulates an enum with a map of its codes
    and descriptions.

    copyright:      Copyright (c) 2010 sociomantic labs. All rights reserved

    version:        September 2010: Initial release

    authors:        Gavin Norman

    This template creates classes which contain a real (anonymous) enum, and an
    associative array mapping from the enum values to their string descriptions,
    allowing two-way lookup between codes <-> descriptions, and an
    implementation of the 'in' operator to tell if a code or description is
    valid.

    This is especially useful for "Const" classes which define a list of command
    or status codes where a kind of reverse lookup is needed, going from a code
    to it's name / description (or vice versa).

    The classes also implement a foreach iterator over the values of the enum.

    The class template takes two parameters:

        1. The base type of the enum - must be an integral type (see
        http://www.digitalmars.com/d/1.0/enum.html).

        2. A variadic list of StringEnumValue structs, specifying the names and
        values of the enum's members.

    Usage example:

    ---

        import ocean.core.StringEnum;
        import tango.util.log.Trace;

        alias StringEnumValue!(int) Code;

        StringEnum!(int,
            Code("first", 1),
            Code("second", 2)
        ) Commands;

        // Getting descriptions of codes
        Trace.formatln("Description for code 1 = {}", Commands.description(1));
        Trace.formatln("Description for code first = {}", Commands.description(Commands.first));

        // Getting codes by description
        Trace.formatln("Code for description 'first' = {}", Commands.code("first"));

        // Testing whether codes exist
        Trace.formatln("1 in enum? {}", 1 in Commands);
        Trace.formatln("first in enum? {}", Commands.first in Commands);
        
        // Testing whether codes exist by description
        Trace.formatln("'first' in enum? {}", "first" in Commands);
        Trace.formatln("'third' in enum? {}", "third" in Commands);

        // Iteration over enum
        foreach ( code, descr; Commands )
        {
            Trace.formatln("{} -> {}", code, descr);
        }

    ---

*******************************************************************************/

module ocean.core.Enum;



/*******************************************************************************

    Struct template representing a single member of an enum - containing a
    string for the enum identifier and a code for the corresponding value.

    Template params:
        T = base type of enum

*******************************************************************************/

struct StringEnumValue ( T = int )
{
    char[] description;
    T code;
}


/*******************************************************************************

    Class template defining an enum with code<->description lookup.

    Template params:
        T = base type of enum
        V = tuple of StringEnumValue structs containing the code->description
            mapping info for the enum (statically asserted to be of the required
            type)

*******************************************************************************/

class StringEnum ( T, V ... )
{
    /***************************************************************************

        Template forming a string containing the declaration of a single value
        in an enum based on the given parameters. Something like:
        
            "Val1 = 1"

        Template params:
            description = enum identifier
            code = enum value

    ***************************************************************************/

    private template EnumValueString ( char[] description, T code )
    {
        const char[] EnumValueString = description ~ " = " ~ code.stringof;
    }


    /***************************************************************************

        Template forming a string containing an enum declaration based on the
        given parameters.

        Template params:
            V = tuple of StringEnumValue structs containing the
                code->description mapping info for the enum (statically asserted
                to be of the required type)
    
    ***************************************************************************/

    private template EnumValueListString ( V ... )
    {
        static if ( V.length == 1 )
        {
            static assert ( is(typeof(V[0]) == StringEnumValue!(T)) );

            const char[] EnumValueListString = EnumValueString!(V[0].description, V[0].code);
        }
        else
        {
            const char[] EnumValueListString = EnumValueListString!(V[0]) ~ ", " ~ EnumValueListString!(V[1..$]);
        }
    }


    /***************************************************************************

        Template forming a string containing an enum declaration based on the
        given parameters.
        
        Template params:
            base = string of the base type of the enum (usually int)
            values = string of the value declaration of the enum, in the
                following format:

                    "Val1 = 1, Val2 = 2" etc
    
    ***************************************************************************/

    private template EnumDeclaration ( char[] base, char[] values )
    {
        const char[] EnumDeclaration = "enum : " ~ base ~ " { " ~ values ~ " }";
        //pragma ( msg, EnumDeclaration );
    }


    /***************************************************************************

        Mixin which creates a real (anonymous) enum in this class's namespace,
        based on the class's template parameters.

    ***************************************************************************/

    static public mixin ( EnumDeclaration!(T.stringof, EnumValueListString!(V)) );


    /***************************************************************************

        Code -> description map
    
    ***************************************************************************/

    static private char[][T] code_to_descr;


    /***************************************************************************

        Static constructor - initialises the code -> description map based on
        the class's template parameters.

    ***************************************************************************/

    static this ( )
    {
        foreach ( v; V )
        {
            code_to_descr[v.code] = v.description;
        }
    }


    /***************************************************************************

        Tells whether the given code is in the enum.
        
        Params:
            test = code to check
        
        Returns:
            true if the code is in the enum
            
    ***************************************************************************/

    static public bool opIn_r ( T test )
    {
        return !!(test in code_to_descr);
    }

    /***************************************************************************

        Tells whether the given description is in the enum.
        
        Params:
            description = description to check
        
        Returns:
            true if the description is in the enum
            
    ***************************************************************************/

    static public bool opIn_r ( char[] description )
    {
        try
        {
            code(description);
        }
        catch
        {
            return false;
        }

        return true;
    }


    /***************************************************************************

        Gets the description for a code.
        
        Params:
            test = code to get description for
        
        Returns:
            the code's description, or "INVALID CODE" if the code isn't in the
                enum
            
    ***************************************************************************/

    static public char[] description ( T test )
    {
        if ( test in code_to_descr )
        {
            return code_to_descr[test];
        }
        else
        {
            return "INVALID CODE";
        }
    }


    /***************************************************************************

        Gets the code corresponding to the given description.
        
        Params:
            description = description to get code for
        
        Returns:
            code corresponding to the description
            
        Throws:
            asserts that the description is in the list
    
    ***************************************************************************/

    static public T code ( char[] description )
    {
        foreach ( code, desc; code_to_descr )
        {
            if ( desc == description )
            {
                return code;
            }
        }

        assert(false, typeof(this).stringof ~ " - no code corresponds to description '" ~ description ~ "'");
    }


    /***************************************************************************

        foreach iterator over the code->description mapping.
    
    ***************************************************************************/

    static public int opApply ( int delegate ( ref T value, ref char[] name ) dg )
    {
        int res;
        foreach ( code, description; code_to_descr )
        {
            res = dg(code, description);
        }
        return res;
    }
}

