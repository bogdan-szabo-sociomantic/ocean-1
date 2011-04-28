/*******************************************************************************

    Smart enum template class, encapsulates an enum with a map of its codes
    and descriptions.

    copyright:      Copyright (c) 2011 sociomantic labs. All rights reserved

    version:        March 2011: Initial release

    authors:        Gavin Norman

    Contains two main mixin templates:

        1. SmartEnum
        2. AutoSmartEnum


    1. SmartEnum
    ----------------------------------------------------------------------------

    Mixin template declaring a class containing an enum with code<->description
    lookup. All methods are static, so that the class can be used without an
    instance.

    This mixin creates classes which contain a real (anonymous) enum, and two
    associative arrays mapping from the enum values to their string descriptions
    and vice versa, allowing two-way lookup between codes <-> descriptions, and
    an implementation of the 'in' operator to tell if a code or description is
    valid.

    This is especially useful for "Const" classes which define a list of command
    or status codes where a kind of reverse lookup is needed, going from a code
    to its name / description (or vice versa).

    The classes also implement a foreach iterator over the values of the enum,
    and several other methods (see SmartEunmCore, below).

    The mixin template takes as parameters the name of the class to be generated
    and a variadic list of SmartEnumValue structs, specifying the names and
    values of the enum's members.
    
    The SmartEnumValue struct is also a template, which takes as parameter the
    base type of the enum, which must be an integral type (see
    http://www.digitalmars.com/d/1.0/enum.html).

    Note that as the class generated by the mixin template contains only static
    members, it is not necessary to actually instantiate it, only to declare the
    class (as demonstrated in the example below).

    Usage example:

    ---

        import ocean.core.SmartEnum;
        import tango.util.log.Trace;

        alias SmartEnumValue!(int) Code;

        mixin(SmartEnum!("Commands",
            Code("first", 1),
            Code("second", 2)
        ));

        // Getting descriptions of codes
        // (Note that the getter methods work like opIn, returning pointers.)
        Trace.formatln("Description for code first = {}", *Commands.description(Commands.first));
        Trace.formatln("Description for code 1 = {}", *Commands.description(1));

        // Getting codes by description
        // (Note that the getter methods work like opIn, returning pointers.)
        Trace.formatln("Code for description 'first' = {}", *Commands.code("first"));

        // Testing whether codes exist
        Trace.formatln("1 in enum? {}", !!(1 in Commands));
        Trace.formatln("first in enum? {}", !!(Commands.first in Commands));

        // Testing whether codes exist by description
        Trace.formatln("'first' in enum? {}", !!("first" in Commands));
        Trace.formatln("'third' in enum? {}", !!("third" in Commands));

        // Iteration over enum
        foreach ( code, descr; Commands )
        {
            Trace.formatln("{} -> {}", code, descr);
        }

    ---

    
    2. AutoSmartEnum
    ----------------------------------------------------------------------------

    Template to automatically create a SmartEnum from a list of strings. The
    enum's base type is specified, and the enum values are automatically
    numbered, starting at 0.

    Usage example:
    
    ---

        import ocean.core.StringEnum;

        mixin(AutoSmartEnum!("Commands", int,
            "first",
            "second"));

    ---

*******************************************************************************/

module ocean.core.SmartEnum;



/*******************************************************************************

    Imports

 *******************************************************************************/

public import ocean.core.TwoWayMap;
public import ocean.core.Exception;

private import ocean.core.Traits;

private import tango.core.Traits;
private import tango.core.Tuple;



/*******************************************************************************

    Abstract base class for SmartEnums. Contains no members, just provided as a
    convenient way of checking that a class is in fact a SmartEnum, using
    is(T : ISmartEnum).

*******************************************************************************/

public abstract class ISmartEnum
{
}



/*******************************************************************************

    Struct template representing a single member of an enum -- containing a
    string for the enum identifier and a code for the corresponding value.

    Template params:
        T = base type of enum

*******************************************************************************/

public struct SmartEnumValue ( T )
{
    alias T BaseType;

    char[] name;
    T value;
}



/*******************************************************************************

    Members forming the core of each class generated by the SmartEnum mixin.
    This template is mixed into each class created by the SmartEnum template.

    Template params:
        BaseType = base type of enum

*******************************************************************************/

private template SmartEnumCore ( BaseType )
{
    /***************************************************************************

        Two way mapping between codes <-> descriptions.

    ***************************************************************************/

    static public TwoWayMap!(char[], BaseType, true) map;


    /***************************************************************************

        Looks up the description of a code.

        Aliased to opIn.

        Params:
            code = code to look up

        Returns:
            pointer to code's description, or null if code not in enum

    ***************************************************************************/

    static public char[]* description ( BaseType code )
    {
        return code in map;
    }

    public alias description opIn_r;


    /***************************************************************************

        Looks up the code of a description.

        Aliased to opIn.

        Params:
            description = description to look up

        Returns:
            pointer to description's code, or null if description not in enum

    ***************************************************************************/

    static public BaseType* code ( char[] description )
    {
        return description in map;
    }

    public alias code opIn_r;

    
    /***************************************************************************

        Gets the description of a code.
    
        Params:
            code = code to look up
    
        Returns:
            code's description
    
        Throws:
            if code is not in the map
    
    ***************************************************************************/

    static public char[] opIndex ( BaseType code )
    {
        auto description = code in map;
        assertEx(description, "code not found in SmartEnum " ~ typeof(this).stringof);
        return *description;
    }


    /***************************************************************************

        Gets the code of a description.
    
        Params:
            description = description to look up
    
        Returns:
            description's code
    
        Throws:
            if description is not in the map
    
    ***************************************************************************/
    
    static public BaseType opIndex ( char[] description )
    {
        auto code = description in map;
        assertEx(code, description ~ " not found in SmartEnum " ~ typeof(this).stringof);
        return *code;
    }


    /***************************************************************************

        Looks up the index of a code in the enum (ie code is the nth code in the
        enum). This can be useful if the actual enum codes are not consecutive.

        Params:
            code = code to get index for

        Returns:
            pointer to code's index, or null if code not in enum

    ***************************************************************************/

    static public size_t* indexOf ( BaseType code )
    {
        return map.indexOf(code);
    }


    /***************************************************************************

        Looks up the index of a description in the enum (ie description is for
        the nth code in the enum).

        Params:
            description = description to get index for

        Returns:
            pointer to description's index, or null if description not in enum

    ***************************************************************************/

    static public size_t* indexOf ( char[] description )
    {
        return map.indexOf(description);
    }


    /***************************************************************************

        Looks up a code in the enum by its index. (ie gets the nth code in the
        enum).

        Params:
            index = index of code to get

        Returns:
            nth code in enum

        Throws:
            array out of bounds if index is > number of codes in the enum

    ***************************************************************************/

    static public BaseType codeFromIndex ( size_t index )
    {
        return map.values[index];
    }


    /***************************************************************************

        Looks up a description in the enum by the index of its code. (ie gets
        the description of the nth code in the enum).
    
        Params:
            index = index of code to get description for

        Returns:
            description of nth code in enum

        Throws:
            array out of bounds if index is > number of codes in the enum

    ***************************************************************************/

    static public char[] descriptionFromIndex ( size_t index )
    {
        return map.keys[index];
    }


    /***************************************************************************

        foreach iterator over the codes and descriptions of the enum.

    ***************************************************************************/

    static public int opApply ( int delegate ( ref BaseType code, ref char[] desc ) dg )
    {
        int res;
        foreach ( description, code; map )
        {
            res = dg(code, description);
        }
        return res;
    }


    /***************************************************************************

        foreach iterator over the codes and descriptions of the enum and their
        indices.

    ***************************************************************************/

    static public int opApply ( int delegate ( ref size_t index, ref BaseType code, ref char[] desc ) dg )
    {
        int res;
        foreach ( index, description, code; map )
        {
            res = dg(index, code, description);
        }
        return res;
    }
}


/*******************************************************************************

    Wrapper for the ctfe_i2a fucntion (see tango.core.Traits), allowing it to
    also handle byte & ubyte types.

*******************************************************************************/

private char[] CTFE_Int2String ( T ) ( T num )
{
    static if ( is(T == ubyte) )
    {
        return ctfe_i2a(cast(uint)num);
    }
    else static if ( is(T == byte) )
    {
        return ctfe_i2a(cast(int)num);
    }
    else
    {
        return ctfe_i2a(num);
    }
}


/*******************************************************************************

    Template to mixin a comma separated list of SmartEnumValues.

    Template params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        first = 1,
        second = 2,
        last = 100
    ---

*******************************************************************************/

private template EnumValuesList ( T ... )
{
    static if ( T.length == 1 )
    {
        const char[] EnumValuesList = T[0].name ~ "=" ~ CTFE_Int2String(T[0].value);
    }
    else
    {
        const char[] EnumValuesList = T[0].name ~ "=" ~ CTFE_Int2String(T[0].value) ~ "," ~ EnumValuesList!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin an enum from a list of SmartEnumValues.

    Template params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:
    
    ---
        enum
        {
            first = 1,
            second = 2,
            last = 100
        }
    ---

*******************************************************************************/

private template DeclareEnum ( T ... )
{
    const char[] DeclareEnum = "alias " ~ T[0].BaseType.stringof ~ " BaseType; enum : BaseType {" ~ EnumValuesList!(T) ~ "} ";
}


/*******************************************************************************

    Template to mixin a series of TwoWayMap value initialisations.
    
    Template params:
        T = variadic list of one or more SmartEnumValues
    
    Generates output of the form:
    
    ---
        map["first"]=1;
        map["second"]=2;
        map["last"]=100;
    ---

*******************************************************************************/

private template InitialiseMap ( T ... )
{
    static if ( T.length == 1 )
    {
        const char[] InitialiseMap = `map["` ~ T[0].name ~ `"]=` ~ T[0].name ~ ";";
    }
    else
    {
        const char[] InitialiseMap = `map["` ~ T[0].name ~ `"]=` ~ T[0].name ~ ";" ~ InitialiseMap!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin a static constructor which initialises and rehashes a
    TwoWayMap.
    
    Template params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:
    
    ---
        static this ( )
        {
            map["first"]=1;
            map["second"]=2;
            map["last"]=100;

            map.rehash;
        }
    ---

*******************************************************************************/

private template StaticThis ( T ... )
{
    const char[] StaticThis = "static this() {" ~ InitialiseMap!(T) ~ "map.rehash;} ";
}


/*******************************************************************************

    Template to find the maximum code from a list of SmartEnumValues.

    Template params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template MaxValue ( T ... )
{
    static if ( T.length == 1 )
    {
        const typeof(T[0].value) MaxValue = T[0].value;
    }
    else
    {
        const typeof(T[0].value) MaxValue = T[0].value > MaxValue!(T[1..$]) ? T[0].value : MaxValue!(T[1..$]);
    }
}


/*******************************************************************************

    Template to find the minimum code from a list of SmartEnumValues.
    
    Template params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template MinValue ( T ... )
{
    static if ( T.length == 1 )
    {
        const typeof(T[0].value) MinValue = T[0].value;
    }
    else
    {
        const typeof(T[0].value) MinValue = T[0].value < MinValue!(T[1..$]) ? T[0].value : MinValue!(T[1..$]);
    }
}


/*******************************************************************************

    Template to find the length of the longest description in a list of
    SmartEnumValues.
    
    Template params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template LongestName ( T ... )
{
    static if ( T.length == 1 )
    {
        const size_t LongestName = T[0].name.length;
    }
    else
    {
        const size_t LongestName = T[0].name.length > LongestName!(T[1..$]) ? T[0].name.length : LongestName!(T[1..$]);
    }
}


/*******************************************************************************

    Template to find the length of the shortest description in a list of
    SmartEnumValues.
    
    Template params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template ShortestName ( T ... )
{
    static if ( T.length == 1 )
    {
        const size_t ShortestName = T[0].name.length;
    }
    else
    {
        const size_t ShortestName = T[0].name.length < ShortestName!(T[1..$]) ? T[0].name.length : ShortestName!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin the declaration of a set of constants.

    Template params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        static const length = 3;
        static const min = 1;
        static const max = 100;
        static const min_descr_length = 4;
        static const max_descr_length = 6;
    ---

*******************************************************************************/

private template DeclareConstants ( T ... )
{
    const char[] DeclareConstants =
        "static const length = " ~ ctfe_i2a(T.length) ~ "; " ~
        "static const min = " ~ CTFE_Int2String(MinValue!(T)) ~ "; " ~
        "static const max = " ~ CTFE_Int2String(MaxValue!(T)) ~ "; " ~
        "static const min_descr_length = " ~ ctfe_i2a(ShortestName!(T)) ~ "; " ~
        "static const max_descr_length = " ~ ctfe_i2a(LongestName!(T)) ~ "; ";
}


/*******************************************************************************

    Template to mixin code for a mixin template declaring the enum class'
    core members.

    Template params:
        T = variadic list of one or more SmartEnumValues

    Generates output of the form:

    ---
        mixin SmartEnumCore!(int);
    ---

*******************************************************************************/

private template MixinCore ( T ... )
{
    const char[] MixinCore = "mixin SmartEnumCore!(" ~ T[0].BaseType.stringof ~ ");";
}


/*******************************************************************************

    Template to check whether any of the names of the tuple of SmartEnumValues
    is a D keyword (which would produce un-compilable code).

    Template params:
        T = variadic list of one or more SmartEnumValues

*******************************************************************************/

private template AllValuesOk ( T ... )
{
    static if ( T.length == 1 )
    {
        const bool AllValuesOk = !isKeyword(T[0].name);
    }
    else
    {
        const bool AllValuesOk = !isKeyword(T[0].name) && AllValuesOk!(T[1..$]);
    }
}


/*******************************************************************************

    Template to mixin a SmartEnum class.

    Template params:
        Name = name of class
        T = variadic list of one or more SmartEnumValues
    
    Generates output of the form:
    
    ---
        class EnumName : ISmartEnum
        {
            // class contents (see templates above)
        }
    ---

*******************************************************************************/

public template SmartEnum ( char[] Name, T ... )
{
    pragma(msg, "Expanding SmartEnum template: " ~ Name);

    static if ( AllValuesOk!(T) )
    {
        static if ( T.length > 0 )
        {
            const char[] SmartEnum = "class " ~ Name ~ " : ISmartEnum { " ~ DeclareEnum!(T) ~
                DeclareConstants!(T) ~ StaticThis!(T) ~ MixinCore!(T) ~ "}";
        }
        else
        {
            static assert(false, "Cannot create a SmartEnum with no entries!");
        }
    }
    else
    {
        static assert(false, "One or more of your enum strings is a D keyword. Cannot compile SmartEnum " ~ Name ~ ".");
    }
}


/*******************************************************************************

    Template to create a tuple of enum codes from 0 to the length of the passed
    tuple of strings.

    Template params:
        BaseType = base type of enum
        i = counter (used recursively)
        Strings = variadic list of descriptions of the enum values

*******************************************************************************/

private template CreateCodes ( BaseType, uint i, Strings ... )
{
    static if ( Strings.length == 1 )
    {
        alias Tuple!(SmartEnumValue!(BaseType)(Strings[0], i)) CreateCodes; 
    }
    else
    {
        alias Tuple!(SmartEnumValue!(BaseType)(Strings[0], i), CreateCodes!(BaseType, i + 1, Strings[1 .. $])) CreateCodes;
    }
}


/*******************************************************************************

    Template to mixin a SmartEnum class with the codes automatically generated,
    starting at 0.

    Template params:
        Name = name of class
        BaseType = base type of enum
        Strings = variadic list of descriptions of the enum values (statically
                  asserted to be char[]s)

*******************************************************************************/

public template AutoSmartEnum ( char[] Name, BaseType, Strings ... )
{
    static assert ( is(typeof(Strings[0]) : char[]), "AutoSmartEnum - please only give char[]s as template parameters");

    const char[] AutoSmartEnum = SmartEnum!(Name, CreateCodes!(BaseType, 0, Strings));
}

