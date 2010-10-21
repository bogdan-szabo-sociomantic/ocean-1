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

    The class template takes as parameters a variadic list of StringEnumValue
    structs, specifying the names and values of the enum's members.

    The StringEnumValue struct is also a template, which takes as parameter the
    base type of the enum - must be an integral type (see
    http://www.digitalmars.com/d/1.0/enum.html).

    Usage example:

    ---

        import ocean.core.StringEnum;
        import tango.util.log.Trace;

        alias StringEnumValue!(int) Code;

        StringEnum!(
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

module ocean.core.StringEnum;



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
        V = tuple of StringEnumValue structs containing the code->description
            mapping info for the enum (statically asserted to be of the required
            type)

*******************************************************************************/

class StringEnum ( V ... )
{
    // FIXME: for some reason neither of these assrtes fires...
    static assert( !is( V == void ), "cannot create a StringEnum with no enum values!" );
    static assert( V.length > 0, "cannot create a StringEnum with no enum values!" );


    /***************************************************************************

        Alias for the base type of the enum. Derived from the base type of the
        first enum value. All StringEnumValues in the tuple V are asserted to be
        of this type (see EnumValueListString, below).
    
    ***************************************************************************/
    
    private alias typeof(V[0].code) T;


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
            static assert ( is(typeof(V[0]) == StringEnumValue!(T)), "all StringEnum values must be based on the same type" );
    
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
    
        Template to find the highest code in a list of StringEnumValues.
    
    ***************************************************************************/
    
    private template EnumMax ( V ... )
    {
        static if ( V.length == 1 )
        {
            const T EnumMax = V[0].code;
        }
        else
        {
            const T EnumMax = V[0].code > EnumMax!(V[1..$]) ? V[0].code : EnumMax!(V[1..$]);
        }
    }
    
    
    /***************************************************************************
    
        Template to find the lowest code in a list of StringEnumValues.
    
    ***************************************************************************/
    
    private template EnumMin ( V ... )
    {
        static if ( V.length == 1 )
        {
            const T EnumMin = V[0].code;
        }
        else
        {
            const T EnumMin = V[0].code < EnumMin!(V[1..$]) ? V[0].code : EnumMin!(V[1..$]);
        }
    }


    /***************************************************************************

        Mixin which creates a real (anonymous) enum in this class's namespace,
        based on the class's template parameters.

    ***************************************************************************/

    static public mixin ( EnumDeclaration!(T.stringof, EnumValueListString!(V)) );


    /***************************************************************************

        Constant declaring the length of the internal enum (the number of
        elements in it).
    
    ***************************************************************************/
    
    static public const size_t length = V.length;


    /***************************************************************************

        Constant declaring the highest code in the internal enum.
    
    ***************************************************************************/

    static public const T max = EnumMax!(V);


    /***************************************************************************

        Constant declaring the lowest code in the internal enum.
    
    ***************************************************************************/

    static public const T min = EnumMin!(V);

    
    /***************************************************************************

        Code -> description map
    
    ***************************************************************************/

    static private char[][T] code_to_descr;


    /***************************************************************************

        Code -> index map (where index represents the nth value in the enum)
    
    ***************************************************************************/

    static private size_t[T] code_to_index;

    
    /***************************************************************************

        Index -> code map (where index represents the nth value in the enum)
    
    ***************************************************************************/

    static private T[length] index_to_code;


    /***************************************************************************

        Static constructor - initialises the internal maps based on the class's
        template parameters.

    ***************************************************************************/

    static this ( )
    {
        foreach ( i, v; V )
        {
            code_to_descr[v.code] = v.description;
            code_to_index[v.code] = i;
            index_to_code[i] = v.code;
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

        Gets the index for a code (where index represents the nth value in the
        enum).
        
        Params:
            test = code to get description for
        
        Returns:
            the code's index in the enum, or the length of the enum if the code
            isn't in the enum
            
    ***************************************************************************/

    static public size_t codeIndex ( T test )
    {
        if ( test in code_to_index )
        {
            return code_to_index[test];
        }
        else
        {
            return length;
        }
    }


    /***************************************************************************

        Gets the code of the nth value in the enum.
        
        Params:
            i = index to get code for
        
        Returns:
            the code of the indexed enum value
            
        Throws:
            asserts that the given index is in range
            
    ***************************************************************************/

    static public T indexCode ( size_t i )
    in
    {
        assert(i < index_to_code.length);
    }
    body
    {
        return index_to_code[i];
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


    /***************************************************************************

        foreach iterator over the code->description mapping, including each
        value's index.
    
    ***************************************************************************/
    
    static public int opApply ( int delegate ( ref size_t index, ref T value, ref char[] name ) dg )
    {
        int res;
        size_t index;
        foreach ( code, description; code_to_descr )
        {
            res = dg(index, code, description);
            index++;
        }
        return res;
    }
}

